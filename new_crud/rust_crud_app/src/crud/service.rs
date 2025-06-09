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
