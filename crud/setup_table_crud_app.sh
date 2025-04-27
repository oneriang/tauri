#!/bin/bash

# 通用表CRUD应用部署脚本
# 文件名: setup_table_crud_app.sh

set -e

# 检查是否以root用户运行
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用root用户运行此脚本!"
  exit 1
fi

# 安装依赖
echo "安装系统依赖..."
apt-get update
apt-get install -y \
  build-essential \
  pkg-config \
  libssl-dev \
  sqlite3 \
  libsqlite3-dev

# 安装Rust
echo "安装Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

# 创建项目目录
PROJECT_DIR="/root/ws/rust/tauri/crud/table_crud_app"
echo "创建项目目录: $PROJECT_DIR"
mkdir -p $PROJECT_DIR/{src,templates,static,migrations}
cd $PROJECT_DIR

# 创建Cargo.toml
echo "创建Cargo.toml..."
cat > Cargo.toml << 'EOF'
[package]
name = "table_crud_app"
version = "0.1.0"
edition = "2021"

[dependencies]
actix-web = "4"
actix-cors = "0.6"
actix-files = "0.6"
askama = { version = "0.11", features = ["with-actix-web"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
sqlx = { version = "0.6", features = ["sqlite", "runtime-tokio-native-tls"] }
tokio = { version = "1.0", features = ["full"] }
uuid = { version = "1.0", features = ["v4"] }
dotenv = "0.15"
log = "0.4"
env_logger = "0.9"
thiserror = "1.0"
EOF

# 创建主程序文件
echo "创建主程序文件..."
cat > src/main.rs << 'EOF'
use actix_cors::Cors;
use actix_web::{web, App, HttpResponse, HttpServer, Responder, get};
use askama::Template;
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
                id: row.try_get("rowid").unwrap_or_else(|_| row.try_get(&columns[0]).unwrap_or(Value::Null).to_string(),
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
                id: row.try_get("rowid").unwrap_or_else(|_| row.try_get(&columns[0]).unwrap_or(Value::Null).to_string(),
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
EOF

# 创建模板文件
echo "创建模板文件..."
mkdir -p templates

cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Table CRUD App</title>
    <link rel="stylesheet" href="/static/style.css">
</head>
<body>
    <div class="container">
        <h1>Database Table CRUD Application</h1>
        <p><a href="/tables">View All Tables</a></p>
    </div>
</body>
</html>
EOF

cat > templates/table_list.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tables List</title>
    <link rel="stylesheet" href="/static/style.css">
</head>
<body>
    <div class="container">
        <h1>Database Tables</h1>
        <ul>
            {% for table in tables %}
            <li><a href="/tables/{{ table }}">{{ table }}</a></li>
            {% endfor %}
        </ul>
    </div>
</body>
</html>
EOF

cat > templates/table_view.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ table_name }} - Table CRUD App</title>
    <link rel="stylesheet" href="/static/style.css">
</head>
<body>
    <div class="container">
        <h1>Table: {{ table_name }}</h1>
        
        <div class="table-actions">
            <button id="add-record-btn">Add Record</button>
        </div>
        
        <table>
            <thead>
                <tr>
                    {% for column in columns %}
                    <th>{{ column.name }} ({{ column.type_ }})</th>
                    {% endfor %}
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                {% for record in records %}
                <tr>
                    {% for column in columns %}
                    <td>{{ record.fields[column.name] }}</td>
                    {% endfor %}
                    <td>
                        <button class="edit-btn" data-id="{{ record.id }}">Edit</button>
                        <button class="delete-btn" data-id="{{ record.id }}">Delete</button>
                    </td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
        
        <div class="pagination">
            {% if pagination.current_page > 1 %}
            <a href="?page={{ pagination.current_page - 1 }}&per_page={{ pagination.per_page }}">Previous</a>
            {% endif %}
            
            <span>Page {{ pagination.current_page }} of {{ pagination.total_pages }}</span>
            
            {% if pagination.current_page < pagination.total_pages %}
            <a href="?page={{ pagination.current_page + 1 }}&per_page={{ pagination.per_page }}">Next</a>
            {% endif %}
        </div>
    </div>

    <div id="record-modal" class="modal" style="display: none;">
        <div class="modal-content">
            <span class="close">&times;</span>
            <h2 id="modal-title">Add Record</h2>
            <form id="record-form">
                {% for column in columns %}
                {% if not column.primary_key %}
                <div class="form-group">
                    <label for="{{ column.name }}">{{ column.name }} ({{ column.type_ }})</label>
                    <input type="text" id="{{ column.name }}" name="{{ column.name }}" 
                           {% if not column.nullable %}required{% endif %}>
                </div>
                {% endif %}
                {% endfor %}
                <button type="submit">Save</button>
            </form>
        </div>
    </div>

    <script src="/static/app.js"></script>
</body>
</html>
EOF

# 创建静态文件
echo "创建静态文件..."
mkdir -p static

cat > static/style.css << 'EOF'
body {
    font-family: Arial, sans-serif;
    line-height: 1.6;
    margin: 0;
    padding: 0;
    color: #333;
}

.container {
    width: 90%;
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

h1 {
    color: #444;
    margin-bottom: 20px;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin: 20px 0;
}

th, td {
    padding: 12px 15px;
    text-align: left;
    border-bottom: 1px solid #ddd;
}

th {
    background-color: #f4f4f4;
    font-weight: bold;
}

tr:hover {
    background-color: #f9f9f9;
}

button {
    padding: 8px 12px;
    background-color: #4CAF50;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    margin-right: 5px;
}

button:hover {
    background-color: #45a049;
}

.delete-btn {
    background-color: #f44336;
}

.delete-btn:hover {
    background-color: #d32f2f;
}

.pagination {
    margin-top: 20px;
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 10px;
}

.modal {
    display: none;
    position: fixed;
    z-index: 1;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    overflow: auto;
    background-color: rgba(0,0,0,0.4);
}

.modal-content {
    background-color: #fefefe;
    margin: 10% auto;
    padding: 20px;
    border: 1px solid #888;
    width: 80%;
    max-width: 600px;
}

.close {
    color: #aaa;
    float: right;
    font-size: 28px;
    font-weight: bold;
    cursor: pointer;
}

.close:hover {
    color: black;
}

.form-group {
    margin-bottom: 15px;
}

.form-group label {
    display: block;
    margin-bottom: 5px;
    font-weight: bold;
}

.form-group input {
    width: 100%;
    padding: 8px;
    box-sizing: border-box;
    border: 1px solid #ddd;
    border-radius: 4px;
}
EOF

cat > static/app.js << 'EOF'
document.addEventListener('DOMContentLoaded', function() {
    const modal = document.getElementById('record-modal');
    const modalTitle = document.getElementById('modal-title');
    const recordForm = document.getElementById('record-form');
    const addBtn = document.getElementById('add-record-btn');
    const closeBtn = document.querySelector('.close');
    let currentRecordId = null;
    
    // 打开添加记录模态框
    if (addBtn) {
        addBtn.addEventListener('click', function() {
            currentRecordId = null;
            modalTitle.textContent = 'Add Record';
            recordForm.reset();
            modal.style.display = 'block';
        });
    }
    
    // 关闭模态框
    closeBtn.addEventListener('click', function() {
        modal.style.display = 'none';
    });
    
    // 点击模态框外部关闭
    window.addEventListener('click', function(event) {
        if (event.target === modal) {
            modal.style.display = 'none';
        }
    });
    
    // 处理表单提交
    if (recordForm) {
        recordForm.addEventListener('submit', function(e) {
            e.preventDefault();
            
            const formData = new FormData(recordForm);
            const data = {};
            formData.forEach((value, key) => {
                data[key] = value;
            });
            
            const tableName = window.location.pathname.split('/')[2];
            const url = currentRecordId 
                ? `/api/tables/${tableName}/records/${currentRecordId}`
                : `/api/tables/${tableName}/records`;
                
            const method = currentRecordId ? 'PUT' : 'POST';
            
            fetch(url, {
                method: method,
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(data),
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    window.location.reload();
                } else {
                    alert(data.error || 'An error occurred');
                }
            })
            .catch(error => {
                console.error('Error:', error);
                alert('An error occurred');
            });
        });
    }
    
    // 绑定编辑按钮
    document.querySelectorAll('.edit-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            currentRecordId = this.getAttribute('data-id');
            modalTitle.textContent = 'Edit Record';
            
            const row = this.closest('tr');
            const inputs = recordForm.querySelectorAll('input');
            
            inputs.forEach(input => {
                const columnName = input.name;
                const cell = row.querySelector(`td:nth-child(${Array.from(row.cells).findIndex(cell => cell.textContent.trim() === row.querySelector(`td[data-column="${columnName}"]`)?.textContent.trim()) + 1})`);
                if (cell) {
                    input.value = cell.textContent.trim();
                }
            });
            
            modal.style.display = 'block';
        });
    });
    
    // 绑定删除按钮
    document.querySelectorAll('.delete-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            if (confirm('Are you sure you want to delete this record?')) {
                const recordId = this.getAttribute('data-id');
                const tableName = window.location.pathname.split('/')[2];
                
                fetch(`/api/tables/${tableName}/records/${recordId}`, {
                    method: 'DELETE',
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        window.location.reload();
                    } else {
                        alert(data.error || 'An error occurred');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    alert('An error occurred');
                });
            }
        });
    });
});
EOF

# 创建数据库迁移
echo "创建数据库迁移..."
cat > migrations/20230101000000_init.sql << 'EOF'
-- 创建示例表
CREATE TABLE IF NOT EXISTS example_table (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 插入示例数据
INSERT INTO example_table (name, description) VALUES 
('First Item', 'This is the first example item'),
('Second Item', 'Another example item with more details');
EOF

# 设置环境变量
echo "设置环境变量..."
cat > .env << 'EOF'
DATABASE_URL=sqlite:table_crud.db
EOF

# 构建项目
echo "构建项目..."
export DATABASE_URL=sqlite:table_crud.db
cargo build --release

# 创建systemd服务
echo "创建systemd服务..."
cat > /etc/systemd/system/table-crud.service << 'EOF'
[Unit]
Description=Table CRUD Application
After=network.target

[Service]
User=root
WorkingDirectory=/root/ws/rust/tauri/crud/table_crud_app
Environment="DATABASE_URL=sqlite:/root/ws/rust/tauri/crud/table_crud_app/table_crud.db"
ExecStart=/root/.cargo/bin/cargo run --release
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
echo "启用并启动服务..."
systemctl daemon-reload
systemctl enable table-crud
systemctl start table-crud

echo "安装完成!"
echo "应用已启动，访问 http://your-server-ip:8000"