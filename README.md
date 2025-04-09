# Rust 和 HTMX 结合的 Web 应用程序实现

下面我将展示一个使用 Rust 后端与 HTMX 前端结合的完整 Web 应用程序示例。我们将使用 Axum 作为 Web 框架，因为它简单高效且与 HTMX 配合良好。

## 项目结构

```
htmx-rust-app/
├── Cargo.toml
├── src/
│   ├── main.rs
│   └── templates/
│       ├── base.html
│       ├── index.html
│       └── partials/
│           └── counter.html
```

## 1. 设置 Cargo.toml

```toml
[package]
name = "htmx-rust-app"
version = "0.1.0"
edition = "2021"

[dependencies]
axum = "0.7"
tokio = { version = "1.0", features = ["full"] }
askama = "0.12" # 模板引擎
serde = { version = "1.0", features = ["derive"] }
tower-http = { version = "0.5", features = ["fs"] }
```

## 2. 主应用程序代码 (src/main.rs)

```rust
use axum::{
    response::{Html, IntoResponse},
    routing::{get, post},
    Form, Router,
};
use askama::Template;
use serde::Deserialize;

#[tokio::main]
async fn main() {
    // 初始化路由
    let app = Router::new()
        .route("/", get(index_handler))
        .route("/increment", post(increment_handler))
        .route("/decrement", post(decrement_handler));

    // 启动服务器
    let listener = tokio::net::TcpListener::bind("127.0.0.1:3000")
        .await
        .unwrap();
    println!("Server running on http://localhost:3000");
    axum::serve(listener, app).await.unwrap();
}

// 处理根路径请求
async fn index_handler() -> impl IntoResponse {
    let template = IndexTemplate { count: 0 };
    Html(template.render().unwrap())
}

// 处理增加计数请求
async fn increment_handler(Form(form): Form<CounterForm>) -> impl IntoResponse {
    let new_count = form.count + 1;
    let template = CounterPartial { count: new_count };
    Html(template.render().unwrap())
}

// 处理减少计数请求
async fn decrement_handler(Form(form): Form<CounterForm>) -> impl IntoResponse {
    let new_count = form.count - 1;
    let template = CounterPartial { count: new_count };
    Html(template.render().unwrap())
}

// 表单数据结构
#[derive(Deserialize)]
struct CounterForm {
    count: i32,
}

// 基础模板
#[derive(Template)]
#[template(path = "base.html")]
struct BaseTemplate {
    title: &'static str,
    content: String,
}

// 首页模板
#[derive(Template)]
#[template(path = "index.html")]
struct IndexTemplate {
    count: i32,
}

// 计数器部分模板
#[derive(Template)]
#[template(path = "partials/counter.html")]
struct CounterPartial {
    count: i32,
}
```

## 3. 模板文件

### 基础模板 (src/templates/base.html)

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ title }}</title>
    <script src="https://unpkg.com/htmx.org@1.9.6"></script>
    <style>
        body {
            font-family: sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        .counter {
            display: flex;
            gap: 10px;
            align-items: center;
            margin: 20px 0;
        }
        button {
            padding: 8px 16px;
            font-size: 16px;
        }
        .count-value {
            font-size: 24px;
            min-width: 50px;
            text-align: center;
        }
    </style>
</head>
<body>
    {{ content|safe }}
</body>
</html>
```

### 首页模板 (src/templates/index.html)

```html
{% extends "base.html" %}

{% block content %}
<h1>HTMX + Rust Counter Example</h1>

<div class="counter">
    <button hx-post="/decrement" hx-target="#counter" hx-include="#counter">
        -
    </button>
    
    <div id="counter">
        {% include "partials/counter.html" %}
    </div>
    
    <button hx-post="/increment" hx-target="#counter" hx-include="#counter">
        +
    </button>
</div>

<p>This is a simple counter example using HTMX with Rust (Axum).</p>
{% endblock %}
```

### 计数器部分模板 (src/templates/partials/counter.html)

```html
<input type="hidden" name="count" value="{{ count }}" />
<div class="count-value">{{ count }}</div>
```

## 如何运行

1. 创建新项目：`cargo new htmx-rust-app`
2. 将上述代码放入相应文件
3. 运行：`cargo run`
4. 访问 `http://localhost:3000`

## 功能说明

这个示例实现了一个简单的计数器应用，展示了：

1. **HTMX 集成**：使用 HTMX 进行无页面刷新交互
2. **部分模板更新**：只更新计数器部分而不是整个页面
3. **表单处理**：通过隐藏的 input 传递当前计数状态
4. **Rust 后端**：使用 Axum 处理 HTTP 请求

## 扩展建议

1. 添加数据库集成（如 SQLx 或 Diesel）
2. 实现更多复杂的 HTMX 模式（如懒加载、无限滚动）
3. 添加 WebSocket 支持实时更新
4. 集成前端构建工具（如 TailwindCSS）
5. 添加用户认证功能

这个示例展示了 Rust 和 HTMX 如何很好地配合创建现代、高效的 Web 应用程序，既保持了 Rust 的性能和安全性，又利用了 HTMX 的简单交互模型。
