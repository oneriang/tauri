use askama::Template;
use crate::models::{Todo, Task, Pagination};

#[derive(Template)]
#[template(path = "crud_todo_list.html")]
pub struct TodoListTemplate {
    pub items: Vec<Todo>,
    pub pagination: Pagination,
}

#[derive(Template)]
#[template(path = "crud_todo_item.html")]
pub struct TodoItemTemplate {
    pub todo: Todo,
}

#[derive(Template)]
#[template(path = "crud_task_list.html")]
pub struct TaskListTemplate {
    pub items: Vec<Task>,
    pub pagination: Pagination,
}

#[derive(Template)]
#[template(path = "crud_task_item.html")]
pub struct TaskItemTemplate {
    pub task: Task,
}