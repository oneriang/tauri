use crate::{
    models::{Task, Pagination, PaginationParams, JsonResponse},
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
