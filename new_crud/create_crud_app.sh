#!/bin/bash

# 创建项目结构
create_project_structure() {
    echo "Creating project structure..."
    mkdir -p rust_crud_app/{src/{models,services,crud},templates,static/{css,js},migrations}
    cd rust_crud_app

    # 初始化Rust项目
    cargo init --name crud_app
    touch src/{main.rs,models.rs,services/mod.rs,crud/mod.rs}
    touch templates/{base.html,crud_todo_list.html,crud_todo_item.html,crud_task_list.html,crud_task_item.html}
    touch static/css/style.css static/js/app.js
    touch migrations/0001_initial.up.sql

    # 创建目录结构
    cat > src/services/mod.rs << 'EOL'
pub mod todo;
pub mod task;
EOL

    cat > src/crud/mod.rs << 'EOL'
pub mod service;
pub mod templates;
EOL
}

# 创建数据库迁移文件
create_migrations() {
    echo "Creating database migrations..."
    cat > migrations/0001_initial.up.sql << 'EOL'
CREATE TABLE todos (
    id TEXT PRIMARY KEY,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    title TEXT NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
);
EOL
}

# 创建模型文件
create_models() {
    echo "Creating models..."
    cat > src/models.rs << 'EOL'
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;
use chrono::NaiveDateTime;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct BaseModel {
    pub id: String,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Todo {
    #[serde(flatten)]
    pub base: BaseModel,
    pub title: String,
    pub completed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Task {
    #[serde(flatten)]
    pub base: BaseModel,
    pub name: String,
    pub description: String,
    pub status: String, // "pending", "in_progress", "completed"
}

#[derive(Debug, Deserialize)]
pub struct PaginationParams {
    pub page: Option<i32>,
    pub per_page: Option<i32>,
}

#[derive(Debug, Serialize)]
pub struct Pagination {
    pub current_page: i32,
    pub per_page: i32,
    pub total: i32,
    pub total_pages: i32,
}

#[derive(Serialize)]
pub struct JsonResponse<T: Serialize> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<String>,
}

impl<T: Serialize> JsonResponse<T> {
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
        }
    }
    
    pub fn error(message: String) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(message),
        }
    }
}
EOL
}

# 创建CRUD服务
create_crud_service() {
    echo "Creating CRUD service..."
    cat > src/crud/service.rs << 'EOL'
use crate::models::{Pagination, PaginationParams};
use askama::Template;
use sqlx::{Pool, Sqlite};
use std::marker::PhantomData;

pub struct CrudService<T> {
    pool: Pool<Sqlite>,
    _marker: PhantomData<T>,
}

impl<T> CrudService<T> {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self {
            pool,
            _marker: PhantomData,
        }
    }
}

impl<T: for<'r> sqlx::FromRow<'r, sqlx::sqlite::SqliteRow> + Send + Unpin> CrudService<T> {
    pub async fn list(
        &self,
        table_name: &str,
        params: PaginationParams,
    ) -> Result<(Vec<T>, Pagination), sqlx::Error> {
        let page = params.page.unwrap_or(1);
        let per_page = params.per_page.unwrap_or(10);
        let offset = (page - 1) * per_page;

        let total: i32 = sqlx::query_scalar(&format!("SELECT COUNT(*) FROM {}", table_name))
            .fetch_one(&self.pool)
            .await?;

        let items = sqlx::query_as::<_, T>(&format!(
            "SELECT * FROM {} ORDER BY created_at DESC LIMIT ? OFFSET ?", 
            table_name
        ))
        .bind(per_page)
        .bind(offset)
        .fetch_all(&self.pool)
        .await?;

        let total_pages = (total as f64 / per_page as f64).ceil() as i32;

        Ok((items, Pagination {
            current_page: page,
            per_page,
            total,
            total_pages,
        }))
    }

    pub async fn get_by_id(
        &self,
        table_name: &str,
        id: &str,
    ) -> Result<Option<T>, sqlx::Error> {
        sqlx::query_as::<_, T>(&format!(
            "SELECT * FROM {} WHERE id = ?", 
            table_name
        ))
        .bind(id)
        .fetch_optional(&self.pool)
        .await
    }

    pub async fn create(
        &self,
        table_name: &str,
    ) -> Result<String, sqlx::Error> {
        let id = uuid::Uuid::new_v4().to_string();
        let now = chrono::Local::now().naive_local();
        
        sqlx::query(&format!(
            "INSERT INTO {} (id, created_at, updated_at) VALUES (?, ?, ?)",
            table_name
        ))
        .bind(&id)
        .bind(now)
        .bind(now)
        .execute(&self.pool)
        .await?;
        
        Ok(id)
    }

    pub async fn update(
        &self,
        table_name: &str,
        id: &str,
        updates: Vec<(&str, String)>,
    ) -> Result<bool, sqlx::Error> {
        let mut query = format!("UPDATE {} SET ", table_name);
        let mut params = Vec::new();
        let now = chrono::Local::now().naive_local().to_string();

        for (i, (field, _)) in updates.iter().enumerate() {
            if i > 0 {
                query.push_str(", ");
            }
            query.push_str(&format!("{} = ?", field));
        }
        
        query.push_str(", updated_at = ? WHERE id = ?");
        
        let mut query = sqlx::query(&query);
        
        for (_, value) in &updates {
            query = query.bind(value);
        }
        
        let result = query
            .bind(now)
            .bind(id)
            .execute(&self.pool)
            .await?;
        
        Ok(result.rows_affected() > 0)
    }

    pub async fn delete(
        &self,
        table_name: &str,
        id: &str,
    ) -> Result<bool, sqlx::Error> {
        let result = sqlx::query(&format!(
            "DELETE FROM {} WHERE id = ?", 
            table_name
        ))
        .bind(id)
        .execute(&self.pool)
        .await?;
        
        Ok(result.rows_affected() > 0)
    }
}
EOL
}

# 创建Todo服务
create_todo_service() {
    echo "Creating Todo service..."
    cat > src/services/todo.rs << 'EOL'
use crate::{
    models::{Todo, PaginationParams, JsonResponse},
    crud::service::CrudService,
};
use sqlx::{Pool, Sqlite};
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
pub struct CreateTodo {
    pub title: String,
}

#[derive(Debug, Deserialize)]
pub struct UpdateTodo {
    pub title: Option<String>,
    pub completed: Option<bool>,
}

pub struct TodoService {
    crud: CrudService<Todo>,
}

impl TodoService {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self {
            crud: CrudService::new(pool),
        }
    }

    pub async fn list_todos(
        &self,
        params: PaginationParams,
    ) -> Result<(Vec<Todo>, Pagination), sqlx::Error> {
        self.crud.list("todos", params).await
    }

    pub async fn get_todo(
        &self,
        id: &str,
    ) -> Result<Option<Todo>, sqlx::Error> {
        self.crud.get_by_id("todos", id).await
    }

    pub async fn create_todo(
        &self,
        data: CreateTodo,
    ) -> Result<Todo, sqlx::Error> {
        let id = self.crud.create("todos").await?;
        
        let todo = Todo {
            base: crate::models::BaseModel {
                id,
                created_at: chrono::Local::now().naive_local(),
                updated_at: chrono::Local::now().naive_local(),
            },
            title: data.title,
            completed: false,
        };
        
        let updates = vec![
            ("title", todo.title.clone()),
            ("completed", todo.completed.to_string()),
        ];
        
        self.crud.update("todos", &todo.base.id, updates).await?;
        
        Ok(todo)
    }

    pub async fn update_todo(
        &self,
        id: &str,
        data: UpdateTodo,
    ) -> Result<Option<Todo>, sqlx::Error> {
        let mut updates = Vec::new();
        
        if let Some(title) = data.title {
            updates.push(("title", title));
        }
        
        if let Some(completed) = data.completed {
            updates.push(("completed", completed.to_string()));
        }
        
        if updates.is_empty() {
            return self.get_todo(id).await;
        }
        
        self.crud.update("todos", id, updates).await?;
        self.get_todo(id).await
    }

    pub async fn delete_todo(
        &self,
        id: &str,
    ) -> Result<bool, sqlx::Error> {
        self.crud.delete("todos", id).await
    }
}
EOL
}

# 创建Task服务
create_task_service() {
    echo "Creating Task service..."
    cat > src/services/task.rs << 'EOL'
use crate::{
    models::{Task, PaginationParams, JsonResponse},
    crud::service::CrudService,
};
use sqlx::{Pool, Sqlite};
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
pub struct CreateTask {
    pub name: String,
    pub description: String,
}

#[derive(Debug, Deserialize)]
pub struct UpdateTask {
    pub name: Option<String>,
    pub description: Option<String>,
    pub status: Option<String>,
}

pub struct TaskService {
    crud: CrudService<Task>,
}

impl TaskService {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self {
            crud: CrudService::new(pool),
        }
    }

    pub async fn list_tasks(
        &self,
        params: PaginationParams,
    ) -> Result<(Vec<Task>, Pagination), sqlx::Error> {
        self.crud.list("tasks", params).await
    }

    pub async fn get_task(
        &self,
        id: &str,
    ) -> Result<Option<Task>, sqlx::Error> {
        self.crud.get_by_id("tasks", id).await
    }

    pub async fn create_task(
        &self,
        data: CreateTask,
    ) -> Result<Task, sqlx::Error> {
        let id = self.crud.create("tasks").await?;
        
        let task = Task {
            base: crate::models::BaseModel {
                id,
                created_at: chrono::Local::now().naive_local(),
                updated_at: chrono::Local::now().naive_local(),
            },
            name: data.name,
            description: data.description,
            status: "pending".to_string(),
        };
        
        let updates = vec![
            ("name", task.name.clone()),
            ("description", task.description.clone()),
            ("status", task.status.clone()),
        ];
        
        self.crud.update("tasks", &task.base.id, updates).await?;
        
        Ok(task)
    }

    pub async fn update_task(
        &self,
        id: &str,
        data: UpdateTask,
    ) -> Result<Option<Task>, sqlx::Error> {
        let mut updates = Vec::new();
        
        if let Some(name) = data.name {
            updates.push(("name", name));
        }
        
        if let Some(description) = data.description {
            updates.push(("description", description));
        }
        
        if let Some(status) = data.status {
            updates.push(("status", status));
        }
        
        if updates.is_empty() {
            return self.get_task(id).await;
        }
        
        self.crud.update("tasks", id, updates).await?;
        self.get_task(id).await
    }

    pub async fn delete_task(
        &self,
        id: &str,
    ) -> Result<bool, sqlx::Error> {
        self.crud.delete("tasks", id).await
    }
}
EOL
}

# 创建模板文件
create_templates() {
    echo "Creating template files..."
    
    # 基础模板
    cat > templates/base.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}CRUD App{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="/static/css/style.css">
    <script src="https://unpkg.com/htmx.org@1.9.6"></script>
</head>
<body>
    <div class="container py-4">
        <nav class="navbar navbar-expand-lg navbar-light bg-light mb-4">
            <div class="container-fluid">
                <a class="navbar-brand" href="/">CRUD App</a>
                <div class="navbar-nav">
                    <a class="nav-link" href="/todos">Todos</a>
                    <a class="nav-link" href="/tasks">Tasks</a>
                </div>
            </div>
        </nav>
        
        {% block content %}{% endblock %}
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="/static/js/app.js"></script>
</body>
</html>
EOL

    # Todo列表模板
    cat > templates/crud_todo_list.html << 'EOL'
{% extends "base.html" %}

{% block title %}Todo List{% endblock %}

{% block content %}
<div class="card">
    <div class="card-header d-flex justify-content-between align-items-center">
        <h2 class="mb-0">Todo List</h2>
        <button class="btn btn-primary" 
                hx-get="/todos/new" 
                hx-target="#todoFormContainer">
            Add New Todo
        </button>
    </div>
    
    <div class="card-body">
        <div id="todoFormContainer"></div>
        
        <div id="todoList">
            {% if items.is_empty() %}
                <div class="alert alert-info">No todos found</div>
            {% else %}
                <div class="list-group">
                    {% for todo in items %}
                        {% include "crud_todo_item.html" %}
                    {% endfor %}
                </div>
            {% endif %}
        </div>
        
        {% if pagination.total_pages > 1 %}
        <nav class="mt-4">
            <ul class="pagination justify-content-center">
                {% if pagination.current_page > 1 %}
                <li class="page-item">
                    <a class="page-link" 
                       hx-get="/todos?page={{ pagination.current_page - 1 }}" 
                       hx-target="#todoList">
                        &laquo; Previous
                    </a>
                </li>
                {% endif %}
                
                {% for page_num in 1..=pagination.total_pages %}
                <li class="page-item {% if page_num == pagination.current_page %}active{% endif %}">
                    <a class="page-link" 
                       hx-get="/todos?page={{ page_num }}" 
                       hx-target="#todoList">
                        {{ page_num }}
                    </a>
                </li>
                {% endfor %}
                
                {% if pagination.current_page < pagination.total_pages %}
                <li class="page-item">
                    <a class="page-link" 
                       hx-get="/todos?page={{ pagination.current_page + 1 }}" 
                       hx-target="#todoList">
                        Next &raquo;
                    </a>
                </li>
                {% endif %}
            </ul>
        </nav>
        {% endif %}
    </div>
</div>
{% endblock %}
EOL

    # Todo单项模板
    cat > templates/crud_todo_item.html << 'EOL'
<div class="list-group-item d-flex justify-content-between align-items-center" 
     id="todo-{{ todo.base.id }}">
    <div class="d-flex align-items-center">
        <form hx-put="/todos/{{ todo.base.id }}" 
              hx-target="#todo-{{ todo.base.id }}" 
              hx-swap="outerHTML">
            <input type="hidden" name="completed" value="{{ !todo.completed }}">
            <button type="submit" class="btn btn-sm {% if todo.completed %}btn-outline-success{% else %}btn-outline-secondary{% endif %} me-2">
                {% if todo.completed %}
                    <i class="bi bi-check-square"></i>
                {% else %}
                    <i class="bi bi-square"></i>
                {% endif %}
            </button>
        </form>
        <span class="{% if todo.completed %}text-decoration-line-through{% endif %}">
            {{ todo.title }}
        </span>
    </div>
    <div class="d-flex">
        <button class="btn btn-sm btn-outline-primary me-2"
                hx-get="/todos/{{ todo.base.id }}/edit"
                hx-target="#todo-{{ todo.base.id }}"
                hx-swap="outerHTML">
            Edit
        </button>
        <form hx-delete="/todos/{{ todo.base.id }}" 
              hx-target="#todoList" 
              hx-swap="innerHTML">
            <button type="submit" class="btn btn-sm btn-outline-danger">
                Delete
            </button>
        </form>
    </div>
</div>
EOL

    # Task列表模板
    cat > templates/crud_task_list.html << 'EOL'
{% extends "base.html" %}

{% block title %}Task List{% endblock %}

{% block content %}
<div class="card">
    <div class="card-header d-flex justify-content-between align-items-center">
        <h2 class="mb-0">Task List</h2>
        <button class="btn btn-primary" 
                hx-get="/tasks/new" 
                hx-target="#taskFormContainer">
            Add New Task
        </button>
    </div>
    
    <div class="card-body">
        <div id="taskFormContainer"></div>
        
        <div id="taskList">
            {% if items.is_empty() %}
                <div class="alert alert-info">No tasks found</div>
            {% else %}
                <div class="list-group">
                    {% for task in items %}
                        {% include "crud_task_item.html" %}
                    {% endfor %}
                </div>
            {% endif %}
        </div>
        
        {% if pagination.total_pages > 1 %}
        <nav class="mt-4">
            <ul class="pagination justify-content-center">
                {% if pagination.current_page > 1 %}
                <li class="page-item">
                    <a class="page-link" 
                       hx-get="/tasks?page={{ pagination.current_page - 1 }}" 
                       hx-target="#taskList">
                        &laquo; Previous
                    </a>
                </li>
                {% endif %}
                
                {% for page_num in 1..=pagination.total_pages %}
                <li class="page-item {% if page_num == pagination.current_page %}active{% endif %}">
                    <a class="page-link" 
                       hx-get="/tasks?page={{ page_num }}" 
                       hx-target="#taskList">
                        {{ page_num }}
                    </a>
                </li>
                {% endfor %}
                
                {% if pagination.current_page < pagination.total_pages %}
                <li class="page-item">
                    <a class="page-link" 
                       hx-get="/tasks?page={{ pagination.current_page + 1 }}" 
                       hx-target="#taskList">
                        Next &raquo;
                    </a>
                </li>
                {% endif %}
            </ul>
        </nav>
        {% endif %}
    </div>
</div>
{% endblock %}
EOL

    # Task单项模板
    cat > templates/crud_task_item.html << 'EOL'
<div class="list-group-item" id="task-{{ task.base.id }}">
    <div class="d-flex justify-content-between align-items-center">
        <div>
            <h5>{{ task.name }}</h5>
            <p class="mb-1">{{ task.description }}</p>
            <span class="badge bg-{% match task.status.as_str() %}
                {% when "pending" %}warning
                {% when "in_progress" %}info
                {% when "completed" %}success
                {% else %}secondary
            {% endmatch %}">
                {{ task.status }}
            </span>
        </div>
        <div class="d-flex">
            <button class="btn btn-sm btn-outline-primary me-2"
                    hx-get="/tasks/{{ task.base.id }}/edit"
                    hx-target="#task-{{ task.base.id }}"
                    hx-swap="outerHTML">
                Edit
            </button>
            <form hx-delete="/tasks/{{ task.base.id }}" 
                  hx-target="#taskList" 
                  hx-swap="innerHTML">
                <button type="submit" class="btn btn-sm btn-outline-danger">
                    Delete
                </button>
            </form>
        </div>
    </div>
</div>
EOL
}

# 创建主程序文件
create_main_file() {
    echo "Creating main.rs..."
    cat > src/main.rs << 'EOL'
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

// 其他路由处理函数...
// 需要为每个路由添加相应的处理函数

// 首页
async fn index() -> impl Responder {
    HttpResponse::Ok()
        .content_type("text/html")
        .body(include_str!("../templates/index.html"))
}
EOL
}

# 创建Cargo.toml
create_cargo_toml() {
    echo "Creating Cargo.toml..."
    cat > Cargo.toml << 'EOL'
[package]
name = "crud_app"
version = "0.1.0"
edition = "2021"

[dependencies]
actix-web = "4"
actix-cors = "0.7"
askama = { version = "0.12", features = ["with-actix-web"] }
serde = { version = "1.0", features = ["derive"] }
sqlx = { version = "0.7", features = ["sqlite", "runtime-tokio-native-tls", "chrono", "migrate"] }
uuid = { version = "1.4", features = ["v4"] }
dotenv = "0.15"
log = "0.4"
env_logger = "0.10"
chrono = "0.4"
tokio = { version = "1.0", features = ["full"] }
EOL
}

# 主执行流程
main() {
    create_project_structure
    create_migrations
    create_models
    create_crud_service
    create_todo_service
    create_task_service
    create_templates
    create_main_file
    create_cargo_toml

    echo "Project created successfully!"
    echo "To run the application:"
    echo "1. cd rust_crud_app"
    echo "2. cargo run"
    echo ""
    echo "Make sure to set DATABASE_URL environment variable"
    echo "Example: export DATABASE_URL=sqlite:./database.db"
}

main