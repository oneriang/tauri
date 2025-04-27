use actix_cors::Cors;
use actix_web::{web, App, HttpResponse, HttpServer, Responder, get};
use askama::Template;
//use askama_actix::TemplateToResponse;  // 新增这行
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{SqlitePool, Row};
use std::collections::HashMap;
use uuid::Uuid;
use actix_files::Files;
use log::{info, error};
use actix_web::middleware::Logger;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("Database error: {0}")]
    DatabaseError(#[from] sqlx::Error),
    #[error("Invalid table name")]
    InvalidTableName,
    #[error("Record not found")]
    RecordNotFound,
    #[error("Validation error: {0}")]
    ValidationError(String),
}

impl actix_web::error::ResponseError for AppError {
    fn error_response(&self) -> HttpResponse {
        match self {
            AppError::DatabaseError(_) => HttpResponse::InternalServerError().json(
                JsonResponse::<()>::error(self.to_string())
            ),
            AppError::InvalidTableName => HttpResponse::BadRequest().json(
                JsonResponse::<()>::error(self.to_string())
            ),
            AppError::RecordNotFound => HttpResponse::NotFound().json(
                JsonResponse::<()>::error(self.to_string())
            ),
            AppError::ValidationError(_) => HttpResponse::BadRequest().json(
                JsonResponse::<()>::error(self.to_string())
            ),
        }
    }
}

#[derive(Serialize, Deserialize, Debug)]
struct Table {
    name: String,
    columns: Vec<Column>,
}

#[derive(Serialize, Deserialize, Debug)]
struct Column {
    name: String,
    type_: String,
    nullable: bool,
    primary_key: bool,
}

#[derive(Serialize, Deserialize, Debug)]
struct Record {
    id: String,
    fields: HashMap<String, Value>,
}

#[derive(Debug, Deserialize)]
struct PaginationParams {
    page: Option<i32>,
    per_page: Option<i32>,
}

#[derive(Serialize)]
struct Pagination {
    current_page: i32,
    per_page: i32,
    total: i32,
    total_pages: i32,
}

#[derive(Serialize)]
struct PaginatedRecords {
    records: Vec<Record>,
    pagination: Pagination,
    table_schema: Table,
}

#[derive(Serialize)]
struct JsonResponse<T: Serialize> {
    success: bool,
    data: Option<T>,
    error: Option<String>,
}

impl<T: Serialize> JsonResponse<T> {
    fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
        }
    }
}

impl JsonResponse<()> {
    fn error(message: String) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(message),
        }
    }
}

#[derive(Template)]
#[template(path = "table_list.html")]
struct TableListTemplate {
    tables: Vec<String>,
}

#[derive(Template)]
#[template(path = "table_view.html")]
struct TableViewTemplate {
    table_name: String,
    records: Vec<Record>,
    columns: Vec<Column>,
    pagination: Pagination,
}

async fn get_db_pool() -> Result<SqlitePool, AppError> {
    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "sqlite:table_crud.db".to_string());
    
    Ok(SqlitePool::connect(&database_url).await?)
}

fn is_valid_identifier(s: &str) -> bool {
    !s.is_empty() && s.chars().all(|c| c.is_alphanumeric() || c == '_')
}

async fn get_table_schema(pool: &SqlitePool, table_name: &str) -> Result<Table, AppError> {
    if !is_valid_identifier(table_name) {
        return Err(AppError::InvalidTableName);
    }

    let columns = sqlx::query(
        r#"
        SELECT name, type, notnull as nullable, pk as primary_key
        FROM pragma_table_info(?)
        ORDER BY cid
        "#
    )
    .bind(table_name)
    .fetch_all(pool)
    .await?
    .into_iter()
    .map(|row| Column {
        name: row.get("name"),
        type_: row.get("type"),
        nullable: !row.get::<i32, _>("nullable") == 1,
        primary_key: row.get::<i32, _>("primary_key") == 1,
    })
    .collect();

    Ok(Table {
        name: table_name.to_string(),
        columns,
    })
}

async fn list_tables(pool: web::Data<SqlitePool>) -> Result<JsonResponse<Vec<String>>, AppError> {
    let tables = sqlx::query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    )
    .fetch_all(pool.get_ref())
    .await?
    .into_iter()
    .map(|row| row.get("name"))
    .collect();

    Ok(JsonResponse::success(tables))
}

async fn get_records(
    pool: web::Data<SqlitePool>,
    table_name: web::Path<String>,
    params: web::Query<PaginationParams>,
) -> Result<JsonResponse<PaginatedRecords>, AppError> {
    let table_name = table_name.into_inner();
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(10);
    let offset = (page - 1) * per_page;

    let table_schema = get_table_schema(pool.get_ref(), &table_name).await?;
    
    let columns: Vec<String> = table_schema.columns.iter()
        .map(|c| c.name.clone())
        .collect();
    
    let query_str = format!(
        "SELECT {} FROM {} LIMIT ? OFFSET ?",
        columns.join(", "), table_name
    );
    
    let records = sqlx::query(&query_str)
        .bind(per_page)
        .bind(offset)
        .fetch_all(pool.get_ref())
        .await?
        .into_iter()
        .map(|row| {
            let mut fields = HashMap::new();
            for col in &columns {
                let value: Value = row.try_get(col).unwrap_or(Value::Null);
                fields.insert(col.clone(), value);
            }
            Record {
                id: row.try_get("rowid").unwrap_or_else(|_| row.try_get(&columns[0]).unwrap_or(Value::Null)).to_string(),
                fields,
            }
        })
        .collect();
    
    let total: i32 = sqlx::query_scalar(&format!("SELECT COUNT(*) FROM {}", table_name))
        .fetch_one(pool.get_ref())
        .await?;
    
    Ok(JsonResponse::success(PaginatedRecords {
        records,
        pagination: Pagination {
            current_page: page,
            per_page,
            total,
            total_pages: (total as f64 / per_page as f64).ceil() as i32,
        },
        table_schema,
    }))
}

async fn create_record(
    pool: web::Data<SqlitePool>,
    table_name: web::Path<String>,
    record_data: web::Json<HashMap<String, Value>>,
) -> Result<JsonResponse<Record>, AppError> {
    let table_name = table_name.into_inner();
    let table_schema = get_table_schema(pool.get_ref(), &table_name).await?;
    
    let columns: Vec<String> = table_schema.columns.iter()
        .filter(|c| !c.primary_key)
        .map(|c| c.name.clone())
        .collect();
    
    let placeholders = columns.iter().map(|_| "?").collect::<Vec<_>>().join(", ");
    let query_str = format!(
        "INSERT INTO {} ({}) VALUES ({}) RETURNING rowid, *",
        table_name,
        columns.join(", "),
        placeholders
    );
    
    let mut query = sqlx::query(&query_str);
    for col in &columns {
        if let Some(value) = record_data.get(col) {
            query = query.bind(value.to_string());
        } else {
            return Err(AppError::ValidationError(format!("Missing field: {}", col)));
        }
    }
    
    let row = query.fetch_one(pool.get_ref()).await?;
    
    let mut fields = HashMap::new();
    for col in &table_schema.columns {
        let value: Value = row.try_get(&col.name).unwrap_or(Value::Null);
        fields.insert(col.name.clone(), value);
    }
    
    Ok(JsonResponse::success(Record {
        id: row.try_get("rowid").unwrap_or(Value::Null).to_string(),
        fields,
    }))
}

async fn update_record(
    pool: web::Data<SqlitePool>,
    path: web::Path<(String, String)>,
    record_data: web::Json<HashMap<String, Value>>,
) -> Result<JsonResponse<Record>, AppError> {
    let (table_name, record_id) = path.into_inner();
    let table_schema = get_table_schema(pool.get_ref(), &table_name).await?;
    
    let pk_column = table_schema.columns.iter()
        .find(|c| c.primary_key)
        .map(|c| c.name.clone())
        .unwrap_or_else(|| "rowid".to_string());
    
    let updates = record_data.iter()
        .filter(|(k, _)| table_schema.columns.iter().any(|c| &c.name == *k))
        .map(|(k, v)| format!("{} = ?", k))
        .collect::<Vec<_>>()
        .join(", ");
    
    if updates.is_empty() {
        return Err(AppError::ValidationError("No valid fields to update".to_string()));
    }
    
    let query_str = format!(
        "UPDATE {} SET {} WHERE {} = ? RETURNING *",
        table_name, updates, pk_column
    );
    
    let mut query = sqlx::query(&query_str);
    for (k, v) in record_data.iter() {
        if table_schema.columns.iter().any(|c| &c.name == k) {
            query = query.bind(v.to_string());
        }
    }
    query = query.bind(record_id);
    
    let row = match query.fetch_one(pool.get_ref()).await {
        Ok(row) => row,
        Err(sqlx::Error::RowNotFound) => return Err(AppError::RecordNotFound),
        Err(e) => return Err(AppError::DatabaseError(e)),
    };
    
    let mut fields = HashMap::new();
    for col in &table_schema.columns {
        let value: Value = row.try_get(&col.name).unwrap_or(Value::Null);
        fields.insert(col.name.clone(), value);
    }
    
    Ok(JsonResponse::success(Record {
        id: record_id,
        fields,
    }))
}

async fn delete_record(
    pool: web::Data<SqlitePool>,
    path: web::Path<(String, String)>,
) -> Result<JsonResponse<String>, AppError> {
    let (table_name, record_id) = path.into_inner();
    let table_schema = get_table_schema(pool.get_ref(), &table_name).await?;
    
    let pk_column = table_schema.columns.iter()
        .find(|c| c.primary_key)
        .map(|c| c.name.clone())
        .unwrap_or_else(|| "rowid".to_string());
    
    let query_str = format!(
        "DELETE FROM {} WHERE {} = ?",
        table_name, pk_column
    );
    
    let result = sqlx::query(&query_str)
        .bind(record_id.clone())
        .execute(pool.get_ref())
        .await?;
    
    if result.rows_affected() == 0 {
        return Err(AppError::RecordNotFound);
    }
    
    Ok(JsonResponse::success(record_id))
}

#[get("/")]
async fn index() -> impl Responder {
    HttpResponse::Ok()
        .content_type("text/html")
        .body(include_str!("../templates/index.html"))
}

#[get("/tables")]
async fn list_tables_html(pool: web::Data<SqlitePool>) -> impl Responder {
    let tables = sqlx::query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    )
    .fetch_all(pool.get_ref())
    .await
    .unwrap()
    .into_iter()
    .map(|row| row.get("name"))
    .collect();

    let template = TableListTemplate { tables };
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

#[get("/tables/{table_name}")]
async fn show_table_html(
    pool: web::Data<SqlitePool>,
    table_name: web::Path<String>,
    params: web::Query<PaginationParams>,
) -> impl Responder {
    let table_name = table_name.into_inner();
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(10);
    let offset = (page - 1) * per_page;

    let table_schema = get_table_schema(pool.get_ref(), &table_name).await.unwrap();
    
    let columns: Vec<String> = table_schema.columns.iter()
        .map(|c| c.name.clone())
        .collect();
    
    let query_str = format!(
        "SELECT {} FROM {} LIMIT ? OFFSET ?",
        columns.join(", "), table_name
    );
    
    let records = sqlx::query(&query_str)
        .bind(per_page)
        .bind(offset)
        .fetch_all(pool.get_ref())
        .await.unwrap()
        .into_iter()
        .map(|row| {
            let mut fields = HashMap::new();
            for col in &columns {
                let value: Value = row.try_get(col).unwrap_or(Value::Null);
                fields.insert(col.clone(), value);
            }
            Record {
                id: row.try_get("rowid").unwrap_or_else(|_| row.try_get(&columns[0]).unwrap_or(Value::Null)).to_string(),
                fields,
            }
        })
        .collect();
    
    let total: i32 = sqlx::query_scalar(&format!("SELECT COUNT(*) FROM {}", table_name))
        .fetch_one(pool.get_ref())
        .await.unwrap();
    
    let template = TableViewTemplate {
        table_name,
        records,
        columns: table_schema.columns,
        pagination: Pagination {
            current_page: page,
            per_page,
            total,
            total_pages: (total as f64 / per_page as f64).ceil() as i32,
        },
    };
    
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    std::env::set_var("RUST_LOG", "info,actix_web=info,sqlx=warn");
    env_logger::init();
    
    dotenv::dotenv().ok();
    info!("Starting Table CRUD application...");

    let pool = get_db_pool().await.unwrap();
    info!("Database pool created");

    // 初始化数据库
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS example_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        "#
    )
    .execute(&pool)
    .await
    .unwrap();

    HttpServer::new(move || {
        App::new()
            .wrap(
                Cors::default()
                    .allow_any_origin()
                    .allow_any_method()
                    .allow_any_header()
                    .max_age(3600),
            )
            .wrap(Logger::default())
            .app_data(web::Data::new(pool.clone()))
            .service(Files::new("/static", "static"))
            .service(index)
            .service(list_tables_html)
            .service(show_table_html)
            .route("/api/tables", web::get().to(list_tables))
            .route("/api/tables/{table_name}", web::get().to(|pool, name| async move {
                get_table_schema(&pool.into_inner(), &name.into_inner())
                    .await
                    .map(|schema| JsonResponse::success(schema))
                    .map_err(|e| e.into())
            }))
            .route("/api/tables/{table_name}/records", web::get().to(get_records))
            .route("/api/tables/{table_name}/records", web::post().to(create_record))
            .route("/api/tables/{table_name}/records/{record_id}", web::put().to(update_record))
            .route("/api/tables/{table_name}/records/{record_id}", web::delete().to(delete_record))
    })
    .bind("0.0.0.0:8000")?
    .run()
    .await
}
