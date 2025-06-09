use crate::{
    models::{Todo, Pagination, PaginationParams, JsonResponse},
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