use actix_cors::Cors;
use actix_web::{web, App, HttpResponse, HttpServer, Responder, get};
use askama::Template;
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use uuid::Uuid;
use actix_files::Files;
use log::{info, error};
use actix_web::middleware::Logger;

// Todo 结构体
#[derive(Serialize, Deserialize, Debug)]
struct Todo {
    id: String,
    title: String,
    completed: bool,
}

// 创建 Todo 请求结构体
#[derive(Deserialize, Debug)]
struct CreateTodo {
    title: String,
}

// 更新 Todo 请求结构体
#[derive(Deserialize, Debug)]
struct UpdateTodo {
    title: String,
    completed: bool,
}

// 分页参数
#[derive(Debug, Deserialize)]
struct PaginationParams {
    page: Option<i32>,
    per_page: Option<i32>,
}

// 分页信息
#[derive(Serialize)]
struct Pagination {
    current_page: i32,
    per_page: i32,
    total: i32,
    total_pages: i32,
}

// Todo 列表模板
#[derive(Template)]
#[template(path = "todo_list.html")]
struct TodoListTemplate {
    todos: Vec<Todo>,
    pagination: Pagination,
}

// Todo 单项模板
#[derive(Template)]
#[template(path = "todo_item.html")]
struct TodoItemTemplate {
    todo: Todo,
}

// 错误模板
#[derive(Template)]
#[template(path = "error.html")]
struct ErrorTemplate {
    message: String,
}

// JSON 响应结构体
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

// 数据库连接池
async fn get_db_pool() -> SqlitePool {
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    info!("Connecting to database at: {}", database_url);
    
    SqlitePool::connect(&database_url).await.unwrap_or_else(|e| {
        error!("Failed to connect to database: {}", e);
        panic!("Failed to connect to database: {}", e);
    })
}

// 获取分页 Todo 列表 (HTML)
async fn get_todos(
    pool: web::Data<SqlitePool>,
    params: web::Query<PaginationParams>,
) -> impl Responder {
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(10);
    let offset = (page - 1) * per_page;

    let total: i32 = sqlx::query_scalar!("SELECT COUNT(*) FROM todos")
        .fetch_one(pool.get_ref())
        .await
        .unwrap();

    let todos = sqlx::query_as!(
        Todo,
        r#"SELECT id as "id!", title as "title!", completed FROM todos LIMIT ? OFFSET ?"#,
        per_page,
        offset
    )
    .fetch_all(pool.get_ref())
    .await
    .unwrap();

    let total_pages = (total as f64 / per_page as f64).ceil() as i32;

    let template = TodoListTemplate {
        todos,
        pagination: Pagination {
            current_page: page,
            per_page,
            total,
            total_pages,
        },
    };
    
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

// 获取分页 Todo 列表 (JSON)
async fn get_todos_json(
    pool: web::Data<SqlitePool>,
    params: web::Query<PaginationParams>,
) -> impl Responder {

    info!("get_todos_json ...");

    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(10);
    let offset = (page - 1) * per_page;

    let total: i32 = match sqlx::query_scalar!("SELECT COUNT(*) FROM todos")
        .fetch_one(pool.get_ref())
        .await
    {
        Ok(count) => count,
        Err(e) => {
            return HttpResponse::InternalServerError().json(JsonResponse::error(
                format!("Database error: {}", e)
            ));
        }
    };

    let todos = match sqlx::query_as!(
        Todo,
        r#"SELECT id as "id!", title as "title!", completed FROM todos LIMIT ? OFFSET ?"#,
        per_page,
        offset
    )
    .fetch_all(pool.get_ref())
    .await
    {
        Ok(todos) => todos,
        Err(e) => {
            return HttpResponse::InternalServerError().json(JsonResponse::error(
                format!("Database error: {}", e)
            ));
        }
    };

    let total_pages = (total as f64 / per_page as f64).ceil() as i32;

    #[derive(Serialize)]
    struct PaginatedTodos {
        todos: Vec<Todo>,
        pagination: Pagination,
    }

    let data = PaginatedTodos {
        todos,
        pagination: Pagination {
            current_page: page,
            per_page,
            total,
            total_pages,
        },
    };

    HttpResponse::Ok().json(JsonResponse::success(data))
}

// 创建新 Todo (HTML)
async fn create_todo(
    pool: web::Data<SqlitePool>,
    todo_data: web::Form<CreateTodo>,
) -> impl Responder {
    if todo_data.title.trim().is_empty() {
        let template = ErrorTemplate { 
            message: "Title cannot be empty".to_string() 
        };
        return HttpResponse::BadRequest()
            .content_type("text/html")
            .body(template.render().unwrap());
    }

    let new_id = Uuid::new_v4().to_string();

    sqlx::query!(
        "INSERT INTO todos (id, title, completed) VALUES (?, ?, ?)",
        new_id,
        todo_data.title,
        false,
    )
    .execute(pool.get_ref())
    .await
    .unwrap();

    let page = 1;
    let per_page = 10;
    let offset = 0;

    let total: i32 = sqlx::query_scalar!("SELECT COUNT(*) FROM todos")
        .fetch_one(pool.get_ref())
        .await
        .unwrap();

    let todos = sqlx::query_as!(
        Todo,
        r#"SELECT id as "id!", title as "title!", completed FROM todos ORDER BY rowid DESC LIMIT ? OFFSET ?"#,
        per_page,
        offset
    )
    .fetch_all(pool.get_ref())
    .await
    .unwrap();

    let total_pages = (total as f64 / per_page as f64).ceil() as i32;

    let template = TodoListTemplate {
        todos,
        pagination: Pagination {
            current_page: page,
            per_page,
            total,
            total_pages,
        },
    };
    
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

// 创建新 Todo (JSON)
async fn create_todo_json(
    pool: web::Data<SqlitePool>,
    todo_data: web::Json<CreateTodo>,
) -> impl Responder {
    if todo_data.title.trim().is_empty() {
        return HttpResponse::BadRequest().json(JsonResponse::error(
            "Title cannot be empty".to_string()
        ));
    }

    let new_id = Uuid::new_v4().to_string();

    match sqlx::query!(
        "INSERT INTO todos (id, title, completed) VALUES (?, ?, ?)",
        new_id,
        todo_data.title,
        false,
    )
    .execute(pool.get_ref())
    .await
    {
        Ok(_) => {
            let new_todo = Todo {
                id: new_id,
                title: todo_data.title.clone(),
                completed: false,
            };
            HttpResponse::Ok().json(JsonResponse::success(new_todo))
        }
        Err(e) => HttpResponse::InternalServerError().json(JsonResponse::error(
            format!("Database error: {}", e)
        )),
    }
}

// 更新 Todo (HTML)
async fn update_todo(
    pool: web::Data<SqlitePool>,
    todo_id: web::Path<String>,
    todo_data: web::Form<UpdateTodo>,
) -> impl Responder {
    let id = todo_id.into_inner();
    
    sqlx::query!(
        "UPDATE todos SET title = ?, completed = ? WHERE id = ?",
        todo_data.title,
        todo_data.completed,
        id,
    )
    .execute(pool.get_ref())
    .await
    .unwrap();

    let updated_todo = Todo {
        id: id.clone(),
        title: todo_data.title.clone(),
        completed: todo_data.completed,
    };

    let template = TodoItemTemplate { todo: updated_todo };
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

// 更新 Todo (JSON)
async fn update_todo_json(
    pool: web::Data<SqlitePool>,
    todo_id: web::Path<String>,
    todo_data: web::Json<UpdateTodo>,
) -> impl Responder {
    let id = todo_id.into_inner();
    
    match sqlx::query!(
        "UPDATE todos SET title = ?, completed = ? WHERE id = ?",
        todo_data.title,
        todo_data.completed,
        id,
    )
    .execute(pool.get_ref())
    .await
    {
        Ok(result) => {
            if result.rows_affected() == 0 {
                return HttpResponse::NotFound().json(JsonResponse::error(
                    "Todo not found".to_string()
                ));
            }

            let updated_todo = Todo {
                id: id.clone(),
                title: todo_data.title.clone(),
                completed: todo_data.completed,
            };

            HttpResponse::Ok().json(JsonResponse::success(updated_todo))
        }
        Err(e) => HttpResponse::InternalServerError().json(JsonResponse::error(
            format!("Database error: {}", e)
        )),
    }
}

// 删除 Todo (HTML)
async fn delete_todo(
    pool: web::Data<SqlitePool>, 
    todo_id: web::Path<String>,
    query: web::Query<PaginationParams>,
) -> impl Responder {
    let id = todo_id.into_inner();
    
    sqlx::query!("DELETE FROM todos WHERE id = ?", id)
        .execute(pool.get_ref())
        .await
        .unwrap();

    let page = query.page.unwrap_or(1);
    let per_page = query.per_page.unwrap_or(10);
    let total: i32 = sqlx::query_scalar!("SELECT COUNT(*) FROM todos")
        .fetch_one(pool.get_ref())
        .await
        .unwrap();
    let total_pages = (total as f64 / per_page as f64).ceil() as i32;
    let current_page = if page > total_pages && total_pages > 0 {
        total_pages
    } else {
        page
    };
    let offset = (current_page - 1) * per_page;
    
    let todos = sqlx::query_as!(
        Todo,
        r#"SELECT id as "id!", title as "title!", completed FROM todos LIMIT ? OFFSET ?"#,
        per_page,
        offset
    )
    .fetch_all(pool.get_ref())
    .await
    .unwrap();
    
    let template = TodoListTemplate {
        todos,
        pagination: Pagination {
            current_page,
            per_page,
            total,
            total_pages,
        },
    };
    
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

// 删除 Todo (JSON)
async fn delete_todo_json(
    pool: web::Data<SqlitePool>, 
    todo_id: web::Path<String>,
) -> impl Responder {
    let id = todo_id.into_inner();
    
    match sqlx::query!("DELETE FROM todos WHERE id = ?", id)
        .execute(pool.get_ref())
        .await
    {
        Ok(result) => {
            if result.rows_affected() == 0 {
                return HttpResponse::NotFound().json(JsonResponse::error(
                    "Todo not found".to_string()
                ));
            }

            HttpResponse::Ok().json(JsonResponse::success(id))
        }
        Err(e) => HttpResponse::InternalServerError().json(JsonResponse::error(
            format!("Database error: {}", e)
        )),
    }
}

// 首页
#[get("/")]
async fn index() -> impl Responder {
    let html = include_str!("../templates/index.html");
    HttpResponse::Ok()
        .content_type("text/html")
        .body(html)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // 初始化日志
    std::env::set_var("RUST_LOG", "info,actix_web=info,sqlx=warn");
    env_logger::init();
    
    info!("Starting DBM application...");

    // 加载环境变量
    dotenv::dotenv().ok();
    info!("Environment variables loaded");

    // 创建数据库连接池
    let pool = get_db_pool().await;
    info!("Database pool created");

    // 创建并运行HTTP服务器
    HttpServer::new(move || {
        App::new()
            // CORS 中间件
            .wrap(
                Cors::default()
                    .allow_any_origin()
                    .allow_any_method()
                    .allow_any_header()
                    .max_age(3600),
            )
            // 日志中间件
            .wrap(Logger::default())
            // 共享数据库连接池
            .app_data(web::Data::new(pool.clone()))
            // 静态文件服务
            .service(Files::new("/static", "static"))
            // HTML 路由
            .service(index)
            .route("/todos", web::get().to(get_todos))
            .route("/todos", web::post().to(create_todo))
            .route("/todos/{id}", web::put().to(update_todo))
            .route("/todos/{id}", web::delete().to(delete_todo))
            // JSON API 路由 - 修正这里！
            .service(
                web::scope("/api")
                    .route("/todos", web::get().to(get_todos_json))
                    .route("/todos", web::post().to(create_todo_json))
                    .route("/todos/{id}", web::put().to(update_todo_json))
                    .route("/todos/{id}", web::delete().to(delete_todo_json))
            )
    })
    .bind("0.0.0.0:8000")?
    .run()
    .await
}