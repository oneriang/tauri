use actix_web::{
    web, App, HttpResponse, HttpServer, Responder, 
    middleware::Logger,
};
use actix_cors::Cors;
use sqlx::SqlitePool;
use dotenv::dotenv;
use askama::Template;
use std::env;

mod models;
mod services;
mod crud;

use services::{todo::TodoService, task::TaskService};
use crate::services::todo::{TodoService, CreateTodo, UpdateTodo};
use crate::services::task::{TaskService, CreateTask, UpdateTask};
use actix_web::{web, HttpResponse, Responder};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();
    env_logger::init_from_env(env_logger::Env::new().default_filter_or("info"));

    let database_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");
    
    let pool = SqlitePool::connect(&database_url)
        .await
        .expect("Failed to create pool");

    // 运行数据库迁移
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("Failed to migrate database");

    let todo_service = TodoService::new(pool.clone());
    let task_service = TaskService::new(pool.clone());

    HttpServer::new(move || {
        App::new()
            .wrap(Cors::permissive())
            .wrap(Logger::default())
            .app_data(web::Data::new(todo_service.clone()))
            .app_data(web::Data::new(task_service.clone()))
            .service(actix_files::Files::new("/static", "./static"))
            // Todo 路由
            .route("/todos", web::get().to(list_todos))
            .route("/todos/new", web::get().to(new_todo_form))
            .route("/todos", web::post().to(create_todo))
            .route("/todos/{id}", web::get().to(get_todo))
            .route("/todos/{id}/edit", web::get().to(edit_todo_form))
            .route("/todos/{id}", web::put().to(update_todo))
            .route("/todos/{id}", web::delete().to(delete_todo))
            // Task 路由
            .route("/tasks", web::get().to(list_tasks))
            .route("/tasks/new", web::get().to(new_task_form))
            .route("/tasks", web::post().to(create_task))
            .route("/tasks/{id}", web::get().to(get_task))
            .route("/tasks/{id}/edit", web::get().to(edit_task_form))
            .route("/tasks/{id}", web::put().to(update_task))
            .route("/tasks/{id}", web::delete().to(delete_task))
            //
            .route("/todos/new", web::get().to(new_todo_form))
            .route("/tasks/new", web::get().to(new_task_form))
            // 首页
            .route("/", web::get().to(index))
    })
    .bind("127.0.0.1:8080")?
    .run()
    .await
}

// Todo 路由处理函数
async fn list_todos(
    service: web::Data<TodoService>,
    params: web::Query<models::PaginationParams>,
) -> impl Responder {
    match service.list_todos(params.into_inner()).await {
        Ok((items, pagination)) => {
            let template = crud::templates::TodoListTemplate { items, pagination };
            HttpResponse::Ok()
                .content_type("text/html")
                .body(template.render().unwrap())
        }
        Err(e) => {
            log::error!("Failed to list todos: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

async fn new_todo_form() -> impl Responder {
    HttpResponse::Ok()
        .content_type("text/html")
        .body(include_str!("../templates/todo_form.html"))
}

async fn new_task_form() -> impl Responder {
    HttpResponse::Ok()
        .content_type("text/html")
        .body(include_str!("../templates/task_form.html"))
}


// Todo 路由处理函数
async fn list_todos(
    service: web::Data<TodoService>,
    params: web::Query<PaginationParams>,
) -> impl Responder {
    match service.list_todos(params.into_inner()).await {
        Ok((items, pagination)) => {
            let template = crud::templates::TodoListTemplate { items, pagination };
            HttpResponse::Ok()
                .content_type("text/html")
                .body(template.render().unwrap())
        }
        Err(e) => {
            log::error!("Failed to list todos: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

async fn create_todo(
    service: web::Data<TodoService>,
    form: web::Form<CreateTodo>,
) -> impl Responder {
    match service.create_todo(form.into_inner()).await {
        Ok(_) => HttpResponse::SeeOther()
            .append_header(("Location", "/todos"))
            .finish(),
        Err(e) => {
            log::error!("Failed to create todo: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

async fn get_todo(
    service: web::Data<TodoService>,
    id: web::Path<String>,
) -> impl Responder {
    match service.get_todo(&id).await {
        Ok(Some(todo)) => {
            let template = crud::templates::TodoItemTemplate { todo };
            HttpResponse::Ok()
                .content_type("text/html")
                .body(template.render().unwrap())
        }
        Ok(None) => HttpResponse::NotFound().finish(),
        Err(e) => {
            log::error!("Failed to get todo: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

async fn edit_todo_form(
    service: web::Data<TodoService>,
    id: web::Path<String>,
) -> impl Responder {
    match service.get_todo(&id).await {
        Ok(Some(todo)) => {
            let html = format!(r#"
                <form hx-put="/todos/{}" hx-target="#todo-{}">
                    <input type="text" name="title" value="{}">
                    <input type="checkbox" name="completed" {}>
                    <button type="submit">Save</button>
                </form>
            "#, 
            todo.base.id, 
            todo.base.id,
            todo.title,
            if todo.completed { "checked" } else { "" });
            HttpResponse::Ok()
                .content_type("text/html")
                .body(html)
        }
        Ok(None) => HttpResponse::NotFound().finish(),
        Err(e) => {
            log::error!("Failed to get todo: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

async fn update_todo(
    service: web::Data<TodoService>,
    id: web::Path<String>,
    form: web::Form<UpdateTodo>,
) -> impl Responder {
    match service.update_todo(&id, form.into_inner()).await {
        Ok(_) => HttpResponse::SeeOther()
            .append_header(("Location", format!("/todos/{}", id)))
            .finish(),
        Err(e) => {
            log::error!("Failed to update todo: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

async fn delete_todo(
    service: web::Data<TodoService>,
    id: web::Path<String>,
) -> impl Responder {
    match service.delete_todo(&id).await {
        Ok(true) => HttpResponse::SeeOther()
            .append_header(("Location", "/todos"))
            .finish(),
        Ok(false) => HttpResponse::NotFound().finish(),
        Err(e) => {
            log::error!("Failed to delete todo: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

// Task 路由处理函数 (类似Todo的)
async fn list_tasks(
    service: web::Data<TaskService>,
    params: web::Query<PaginationParams>,
) -> impl Responder {
    match service.list_tasks(params.into_inner()).await {
        Ok((items, pagination)) => {
            let template = crud::templates::TaskListTemplate { items, pagination };
            HttpResponse::Ok()
                .content_type("text/html")
                .body(template.render().unwrap())
        }
        Err(e) => {
            log::error!("Failed to list tasks: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

// 其他Task路由处理函数...
// 其他路由处理函数...
// 需要为每个路由添加相应的处理函数

// 首页
async fn index() -> impl Responder {
    HttpResponse::Ok()
        .content_type("text/html")
        .body(include_str!("../templates/index.html"))
}
