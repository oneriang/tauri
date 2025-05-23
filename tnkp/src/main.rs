use actix_cors::Cors;
use actix_web::{web, App, HttpResponse, HttpServer, Responder, get};
use askama::Template;
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use actix_files::Files;
use log::{info, error};
use actix_web::middleware::Logger;

// 構造体 ---------------------------------------------------------

// m_users テーブルの構造体 ---------------------------------------------------------

// m_users 構造体
#[derive(Serialize, Deserialize, Debug, Clone)]
struct MUser {
    id: i64,
    userid: String,
    passwd: String,
    fname: String,
    lname: String,
    permission: i64,
    facilitator: i64,
    delflg: i64,
}

// 作成/更新用のリクエスト構造体
#[derive(Deserialize, Debug)]
struct CreateMUser {
    userid: String,
    passwd: String,
    fname: String,
    lname: String,
    permission: i64,
    facilitator: i64,
}

#[derive(Deserialize, Debug)]
struct UpdateMUser {
    userid: Option<String>,
    passwd: Option<String>,
    fname: Option<String>,
    lname: Option<String>,
    permission: Option<i64>,
    facilitator: Option<i64>,
    delflg: Option<i64>,
}

// --------------------------------------------------------- m_users テーブルの構造体

// t_work テーブルの構造体 ---------------------------------------------------------

// t_work 结构体
#[derive(Serialize, Deserialize, Debug, Clone)]
struct TWork {
    id: i64,
    customer_id: i64,
    slip_number: String,
    title: String,
    facilitator_id: String,
    version_id: i64,
    os_id: i64,
    folder_id: i64,
    delflg: i64,
    mountflg: i64,
    mountflgstr: Option<String>,
}

// 创建用请求结构体
#[derive(Deserialize, Debug)]
struct CreateTWork {
    customer_id: i64,
    slip_number: String,
    title: String,
    facilitator_id: String,
    version_id: i64,
    os_id: i64,
    folder_id: i64,
}

// 更新用请求结构体
#[derive(Deserialize, Debug)]
struct UpdateTWork {
    customer_id: Option<i64>,
    slip_number: Option<String>,
    title: Option<String>,
    facilitator_id: Option<String>,
    version_id: Option<i64>,
    os_id: Option<i64>,
    folder_id: Option<i64>,
    delflg: Option<i64>,
    mountflg: Option<i64>,
    mountflgstr: Option<String>,
}

// --------------------------------------------------------- t_work テーブルの構造体

// t_work_sub テーブルの構造体 ---------------------------------------------------------

// t_work_sub 结构体
#[derive(Serialize, Deserialize, Debug, Clone)]
struct TWorkSub {
    id: i64,
    work_id: i64,
    workclass_id: i64,
    urtime: Option<String>,  // 使用Option处理可能的NULL值
    mtime: Option<String>,
    durtime: Option<String>,
    comment: String,
    working_user_id: i64,
    delflg: i64,
}

// 创建用请求结构体
#[derive(Deserialize, Debug)]
struct CreateTWorkSub {
    work_id: i64,
    workclass_id: i64,
    urtime: Option<String>,
    mtime: Option<String>,
    durtime: Option<String>,
    comment: String,
    working_user_id: i64,
}

// 更新用请求结构体
#[derive(Deserialize, Debug)]
struct UpdateTWorkSub {
    work_id: Option<i64>,
    workclass_id: Option<i64>,
    urtime: Option<String>,
    mtime: Option<String>,
    durtime: Option<String>,
    comment: Option<String>,
    working_user_id: Option<i64>,
    delflg: Option<i64>,
}

// --------------------------------------------------------- t_work_sub テーブルの構造体


// ページング構造体 ---------------------------------------------------------

// ページングパラメータ
#[derive(Debug, Deserialize)]
struct PaginationParams {
    page: Option<i32>,
    per_page: Option<i32>,
}

// ページング情報
#[derive(Serialize)]
struct Pagination {
    current_page: i32,
    per_page: i32,
    total: i32,
    total_pages: i32,
}

// --------------------------------------------------------- ページング構造体

// --------------------------------------------------------- 構造体

// テンプレート --------------------------------------------------------- 

// users --------------------------------------------------------- 

// CRUD ユーザー管理画面テンプレート
#[derive(Template)]
#[template(path = "users.html")]
struct UsersTemplate {
    users: Vec<MUser>,
    pagination: Pagination
}

// CRUD ユーザーリスト部分テンプレート
#[derive(Template)]
#[template(path = "users_list.html")]
struct UsersListTemplate {
    users: Vec<MUser>,
    pagination: Pagination
}

#[derive(Template)]
#[template(path = "users_item.html")]
struct UsersItemTemplate {
    user: MUser
}

// 添加新的编辑表单テンプレート
#[derive(Template)]
#[template(path = "users_edit.html")]
struct UsersEditTemplate {
    user: MUser,
}

// --------------------------------------------------------- users

// works --------------------------------------------------------- 

// テンプレート结构体
#[derive(Template)]
#[template(path = "works.html")]
struct WorksTemplate {
    works: Vec<TWork>,
    pagination: Pagination
}

#[derive(Template)]
#[template(path = "works_list.html")]
struct WorksListTemplate {
    works: Vec<TWork>,
    pagination: Pagination
}

#[derive(Template)]
#[template(path = "works_item.html")]
struct WorksItemTemplate {
    work: TWork
}

#[derive(Template)]
#[template(path = "works_edit.html")]
struct WorksEditTemplate {
    work: TWork
}

// --------------------------------------------------------- works

// t_work_sub テンプレート -------------------------------------------------

#[derive(Template)]
#[template(path = "work_subs.html")]
struct WorkSubsTemplate {
    work_subs: Vec<TWorkSub>,
    work_id: i64,
    pagination: Pagination
}

#[derive(Template)]
#[template(path = "work_subs_list.html")]
struct WorkSubsListTemplate {
    work_subs: Vec<TWorkSub>,
    work_id: i64,
    pagination: Pagination
}

#[derive(Template)]
#[template(path = "work_subs_item.html")]
struct WorkSubsItemTemplate {
    work_sub: TWorkSub
}

#[derive(Template)]
#[template(path = "work_subs_edit.html")]
struct WorkSubsEditTemplate {
    work_sub: TWorkSub
}

// ------------------------------------------------- t_work_sub テンプレート


// error テンプレート ---------------------------------------------------------

// エラーテンプレート
#[derive(Template)]
#[template(path = "error.html")]
struct ErrorTemplate {
    message: String,
}

// --------------------------------------------------------- error テンプレート

// --------------------------------------------------------- テンプレート

// 処理関数 --------------------------------------------------------- 

// users --------------------------------------------------------- 

// ユーザー管理UI
async fn users_ui(
    pool: web::Data<SqlitePool>,
    params: web::Query<PaginationParams>,
) -> impl Responder {
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(10);
    let offset = (page - 1) * per_page;

    let total: i32 = sqlx::query_scalar!("SELECT COUNT(*) FROM m_users WHERE delflg = 0")
        .fetch_one(pool.get_ref())
        .await
        .unwrap();

    let users = sqlx::query_as!(
        MUser,
        r#"SELECT id, userid, passwd, fname, lname, permission, facilitator, delflg 
           FROM m_users 
           WHERE delflg = 0 
           ORDER BY id DESC LIMIT ? OFFSET ?"#,
        per_page,
        offset
    )
    .fetch_all(pool.get_ref())
    .await
    .unwrap();

    let total_pages = (total as f64 / per_page as f64).ceil() as i32;

    let template = UsersTemplate {
        users,
        pagination: Pagination {
            current_page: page,
            per_page,
            total,
            total_pages,
        }
    };
    
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

// ユーザーリスト部分取得
async fn users_list(
    pool: web::Data<SqlitePool>,
    params: web::Query<PaginationParams>,
) -> HttpResponse {  // impl Responder → HttpResponse に変更
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(10);
    let offset = (page - 1) * per_page;

    let total: i32 = sqlx::query_scalar!("SELECT COUNT(*) FROM m_users WHERE delflg = 0")
        .fetch_one(pool.get_ref())
        .await
        .unwrap();

    let users = sqlx::query_as!(
        MUser,
        r#"SELECT id, userid, passwd, fname, lname, permission, facilitator, delflg 
           FROM m_users 
           WHERE delflg = 0 
           ORDER BY id DESC LIMIT ? OFFSET ?"#,
        per_page,
        offset
    )
    .fetch_all(pool.get_ref())
    .await
    .unwrap();

    let total_pages = (total as f64 / per_page as f64).ceil() as i32;

    let template = UsersListTemplate {
        users,
        pagination: Pagination {
            current_page: page,
            per_page,
            total,
            total_pages,
        }
    };
    
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

// 新規ユーザー作成
async fn create_user(
    pool: web::Data<SqlitePool>,
    user_data: web::Form<CreateMUser>,
) -> HttpResponse {  // impl Responder → HttpResponse に変更
    if user_data.userid.trim().is_empty() || user_data.fname.trim().is_empty() || user_data.lname.trim().is_empty() {
        let template = ErrorTemplate { 
            message: "Required fields cannot be empty".to_string() 
        };
        return HttpResponse::BadRequest()
            .content_type("text/html")
            .body(template.render().unwrap());
    }

    match sqlx::query!(
        "INSERT INTO m_users (userid, passwd, fname, lname, permission, facilitator, delflg) 
         VALUES (?, ?, ?, ?, ?, ?, 0)",
        user_data.userid,
        user_data.passwd,
        user_data.fname,
        user_data.lname,
        user_data.permission,
        user_data.facilitator,
    )
    .execute(pool.get_ref())
    .await {
        Ok(_) => users_list(pool, web::Query(PaginationParams { page: Some(1), per_page: Some(10) })).await,
        Err(e) => {
            error!("Failed to create user: {}", e);
            let template = ErrorTemplate { 
                message: format!("Failed to create user: {}", e)
            };
            HttpResponse::InternalServerError()
                .content_type("text/html")
                .body(template.render().unwrap())
        }
    }
}

// ユーザー更新
async fn update_user(
    pool: web::Data<SqlitePool>,
    user_id: web::Path<i64>,
    user_data: web::Form<UpdateMUser>,
    query: web::Query<PaginationParams>,
) -> impl Responder {
    let id = user_id.into_inner();
    
    // 現在のユーザー情報を取得
    let current_user = match sqlx::query_as!(
        MUser,
        r#"SELECT id, userid, passwd, fname, lname, permission, facilitator, delflg 
           FROM m_users WHERE id = ?"#,
        id
    )
    .fetch_optional(pool.get_ref())
    .await {
        Ok(Some(user)) => user,
        Ok(None) => {
            return HttpResponse::NotFound().body("User not found");
        },
        Err(e) => {
            error!("Failed to fetch user: {}", e);
            return HttpResponse::InternalServerError().body("Internal server error");
        }
    };
    
    // 更新する値を決定
    let new_userid = user_data.userid.as_ref().unwrap_or(&current_user.userid);
    let new_passwd = user_data.passwd.as_ref().unwrap_or(&current_user.passwd);
    let new_fname = user_data.fname.as_ref().unwrap_or(&current_user.fname);
    let new_lname = user_data.lname.as_ref().unwrap_or(&current_user.lname);
    let new_permission = user_data.permission.unwrap_or(current_user.permission);
    let new_facilitator = user_data.facilitator.unwrap_or(current_user.facilitator);
    let new_delflg = user_data.delflg.unwrap_or(current_user.delflg);
    
    // データベース更新
    match sqlx::query!(
        "UPDATE m_users SET 
            userid = ?, 
            passwd = ?, 
            fname = ?, 
            lname = ?, 
            permission = ?, 
            facilitator = ?, 
            delflg = ? 
         WHERE id = ?",
        new_userid,
        new_passwd,
        new_fname,
        new_lname,
        new_permission,
        new_facilitator,
        new_delflg,
        id,
    )
    .execute(pool.get_ref())
    .await {
        Ok(result) => {
            if result.rows_affected() == 0 {
                return HttpResponse::NotFound().body("User not found");
            }
            users_list(pool, query).await
        }
        Err(e) => {
            error!("Failed to update user: {}", e);
            HttpResponse::InternalServerError().body("Failed to update user")
        }
    }
}

// ユーザー削除 (論理削除)
async fn delete_user(
    pool: web::Data<SqlitePool>, 
    user_id: web::Path<i64>,
    query: web::Query<PaginationParams>,
) -> impl Responder {
    let id = user_id.into_inner();
    
    match sqlx::query!(
        "UPDATE m_users SET delflg = 1 WHERE id = ?",
        id
    )
    .execute(pool.get_ref())
    .await {
        Ok(result) => {
            if result.rows_affected() == 0 {
                return HttpResponse::NotFound().body("User not found");
            }
            users_list(pool, query).await
        }
        Err(e) => {
            error!("Failed to delete user: {}", e);
            HttpResponse::InternalServerError().body("Failed to delete user")
        }
    }
}


// 添加新的编辑表单端点
async fn edit_user_form(
    pool: web::Data<SqlitePool>,
    user_id: web::Path<i64>,
) -> HttpResponse {
    let id = user_id.into_inner();
    let user = match sqlx::query_as!(
        MUser,
        r#"SELECT id, userid, passwd, fname, lname, permission, facilitator, delflg 
           FROM m_users WHERE id = ?"#,
        id
    )
    .fetch_optional(pool.get_ref())
    .await {
        Ok(Some(user)) => user,
        Ok(None) => return HttpResponse::NotFound().body("User not found"),
        Err(e) => {
            error!("Failed to fetch user: {}", e);
            return HttpResponse::InternalServerError().body("Internal server error");
        }
    };

    let template = UsersEditTemplate { user };
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

// --------------------------------------------------------- users


// works --------------------------------------------------------- 

// t_work 相关处理函数
async fn works_ui(
    pool: web::Data<SqlitePool>,
    params: web::Query<PaginationParams>,
) -> impl Responder {
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(10);
    let offset = (page - 1) * per_page;

    let total: i32 = sqlx::query_scalar!("SELECT COUNT(*) FROM t_work WHERE delflg = 0")
        .fetch_one(pool.get_ref())
        .await
        .unwrap();

    let works = sqlx::query_as!(
        TWork,
        r#"SELECT id, customer_id, slip_number, title, facilitator_id, 
                  version_id, os_id, folder_id, delflg, mountflg, mountflgstr
           FROM t_work 
           WHERE delflg = 0 
           ORDER BY id DESC LIMIT ? OFFSET ?"#,
        per_page,
        offset
    )
    .fetch_all(pool.get_ref())
    .await
    .unwrap();

    let total_pages = (total as f64 / per_page as f64).ceil() as i32;

    let template = WorksTemplate {
        works,
        pagination: Pagination {
            current_page: page,
            per_page,
            total,
            total_pages,
        }
    };
    
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

async fn works_list(
    pool: web::Data<SqlitePool>,
    params: web::Query<PaginationParams>,
) -> HttpResponse {
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(10);
    let offset = (page - 1) * per_page;

    let total: i32 = sqlx::query_scalar!("SELECT COUNT(*) FROM t_work WHERE delflg = 0")
        .fetch_one(pool.get_ref())
        .await
        .unwrap();

    let works = sqlx::query_as!(
        TWork,
        r#"SELECT id, customer_id, slip_number, title, facilitator_id, 
                  version_id, os_id, folder_id, delflg, mountflg, mountflgstr
           FROM t_work 
           WHERE delflg = 0 
           ORDER BY id DESC LIMIT ? OFFSET ?"#,
        per_page,
        offset
    )
    .fetch_all(pool.get_ref())
    .await
    .unwrap();

    let total_pages = (total as f64 / per_page as f64).ceil() as i32;

    let template = WorksListTemplate {
        works,
        pagination: Pagination {
            current_page: page,
            per_page,
            total,
            total_pages,
        }
    };
    
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

async fn create_work(
    pool: web::Data<SqlitePool>,
    work_data: web::Form<CreateTWork>,
) -> HttpResponse {
    // バリデーション
    if work_data.slip_number.trim().is_empty() 
        || work_data.title.trim().is_empty()
        || work_data.facilitator_id.trim().is_empty() {
        
        let template = ErrorTemplate { 
            message: "必須項目が入力されていません".to_string() 
        };
        return HttpResponse::BadRequest()
            .content_type("text/html")
            .body(template.render().unwrap());
    }

    match sqlx::query!(
        r#"INSERT INTO t_work 
           (customer_id, slip_number, title, facilitator_id, 
            version_id, os_id, folder_id, delflg, mountflg)
           VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0)"#,
        work_data.customer_id,
        work_data.slip_number,
        work_data.title,
        work_data.facilitator_id,
        work_data.version_id,
        work_data.os_id,
        work_data.folder_id,
    )
    .execute(pool.get_ref())
    .await {
        Ok(_) => works_list(pool, web::Query(PaginationParams { page: Some(1), per_page: Some(10) })).await,
        Err(e) => {
            error!("作業作成失敗: {}", e);
            let template = ErrorTemplate { 
                message: format!("作業作成失敗: {}", e)
            };
            HttpResponse::InternalServerError()
                .content_type("text/html")
                .body(template.render().unwrap())
        }
    }
}

async fn update_work(
    pool: web::Data<SqlitePool>,
    work_id: web::Path<i64>,
    work_data: web::Form<UpdateTWork>,
    query: web::Query<PaginationParams>,
) -> impl Responder {
    let id = work_id.into_inner();
    
    // 現在の作業情報を取得
    let current_work = match sqlx::query_as!(
        TWork,
        r#"SELECT id, customer_id, slip_number, title, facilitator_id, 
                  version_id, os_id, folder_id, delflg, mountflg, mountflgstr
           FROM t_work WHERE id = ?"#,
        id
    )
    .fetch_optional(pool.get_ref())
    .await {
        Ok(Some(work)) => work,
        Ok(None) => return HttpResponse::NotFound().body("作業が見つかりません"),
        Err(e) => {
            error!("作業取得失敗: {}", e);
            return HttpResponse::InternalServerError().body("内部サーバーエラー");
        }
    };
    
    // 更新する値を決定
    let new_customer_id = work_data.customer_id.unwrap_or(current_work.customer_id);
    let new_slip_number = work_data.slip_number.as_ref().unwrap_or(&current_work.slip_number);
    let new_title = work_data.title.as_ref().unwrap_or(&current_work.title);
    let new_facilitator_id = work_data.facilitator_id.as_ref().unwrap_or(&current_work.facilitator_id);
    let new_version_id = work_data.version_id.unwrap_or(current_work.version_id);
    let new_os_id = work_data.os_id.unwrap_or(current_work.os_id);
    let new_folder_id = work_data.folder_id.unwrap_or(current_work.folder_id);
    let new_delflg = work_data.delflg.unwrap_or(current_work.delflg);
    let new_mountflg = work_data.mountflg.unwrap_or(current_work.mountflg);
    
    // 修复临时值问题
    let mountflgstr = match &work_data.mountflgstr {
        Some(s) => s.as_str(),
        None => current_work.mountflgstr.as_deref().unwrap_or(""),
    };
    
    match sqlx::query!(
        r#"UPDATE t_work SET 
            customer_id = ?, 
            slip_number = ?, 
            title = ?, 
            facilitator_id = ?, 
            version_id = ?, 
            os_id = ?, 
            folder_id = ?, 
            delflg = ?, 
            mountflg = ?,
            mountflgstr = ?
         WHERE id = ?"#,
        new_customer_id,
        new_slip_number,
        new_title,
        new_facilitator_id,
        new_version_id,
        new_os_id,
        new_folder_id,
        new_delflg,
        new_mountflg,
        mountflgstr,
        id,
    )
    .execute(pool.get_ref())
    .await {
        Ok(result) => {
            if result.rows_affected() == 0 {
                return HttpResponse::NotFound().body("作業が見つかりません");
            }
            works_list(pool, query).await
        }
        Err(e) => {
            error!("作業更新失敗: {}", e);
            HttpResponse::InternalServerError().body("作業更新失敗")
        }
    }
}

async fn delete_work(
    pool: web::Data<SqlitePool>, 
    work_id: web::Path<i64>,
    query: web::Query<PaginationParams>,
) -> impl Responder {
    let id = work_id.into_inner();
    
    match sqlx::query!(
        "UPDATE t_work SET delflg = 1 WHERE id = ?",
        id
    )
    .execute(pool.get_ref())
    .await {
        Ok(result) => {
            if result.rows_affected() == 0 {
                return HttpResponse::NotFound().body("作業が見つかりません");
            }
            works_list(pool, query).await
        }
        Err(e) => {
            error!("作業削除失敗: {}", e);
            HttpResponse::InternalServerError().body("作業削除失敗")
        }
    }
}

async fn edit_work_form(
    pool: web::Data<SqlitePool>,
    work_id: web::Path<i64>,
) -> HttpResponse {
    let id = work_id.into_inner();
    let work = match sqlx::query_as!(
        TWork,
        r#"SELECT id, customer_id, slip_number, title, facilitator_id, 
                  version_id, os_id, folder_id, delflg, mountflg, mountflgstr
           FROM t_work WHERE id = ?"#,
        id
    )
    .fetch_optional(pool.get_ref())
    .await {
        Ok(Some(work)) => work,
        Ok(None) => return HttpResponse::NotFound().body("作業が見つかりません"),
        Err(e) => {
            error!("作業取得失敗: {}", e);
            return HttpResponse::InternalServerError().body("内部サーバーエラー");
        }
    };

    let template = WorksEditTemplate { work };
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

// --------------------------------------------------------- works

// t_work_sub 相关处理函数 -------------------------------------------------

// 工作子项管理UI
async fn work_subs_ui(
    pool: web::Data<SqlitePool>,
    work_id: web::Path<i64>,
    params: web::Query<PaginationParams>,
) -> impl Responder {
    let work_id = work_id.into_inner();
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(10);
    let offset = (page - 1) * per_page;

    let total: i32 = sqlx::query_scalar!(
        "SELECT COUNT(*) FROM t_work_sub WHERE work_id = ? AND delflg = 0",
        work_id
    )
    .fetch_one(pool.get_ref())
    .await
    .unwrap();

    let work_subs = sqlx::query_as!(
        TWorkSub,
        r#"SELECT id, work_id, workclass_id, urtime, mtime, durtime, 
                  comment, working_user_id, delflg
           FROM t_work_sub 
           WHERE work_id = ? AND delflg = 0
           ORDER BY id DESC LIMIT ? OFFSET ?"#,
        work_id,
        per_page,
        offset
    )
    .fetch_all(pool.get_ref())
    .await
    .unwrap();

    let total_pages = (total as f64 / per_page as f64).ceil() as i32;

    let template = WorkSubsTemplate {
        work_subs,
        work_id,
        pagination: Pagination {
            current_page: page,
            per_page,
            total,
            total_pages,
        }
    };
    
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

// 工作子项列表部分
async fn work_subs_list(
    pool: web::Data<SqlitePool>,
    work_id: web::Path<i64>,
    params: web::Query<PaginationParams>,
) -> HttpResponse {
    let work_id = work_id.into_inner();
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(10);
    let offset = (page - 1) * per_page;

    let total: i32 = sqlx::query_scalar!(
        "SELECT COUNT(*) FROM t_work_sub WHERE work_id = ? AND delflg = 0",
        work_id
    )
    .fetch_one(pool.get_ref())
    .await
    .unwrap();

    let work_subs = sqlx::query_as!(
        TWorkSub,
        r#"SELECT id, work_id, workclass_id, urtime, mtime, durtime, 
                  comment, working_user_id, delflg
           FROM t_work_sub 
           WHERE work_id = ? AND delflg = 0
           ORDER BY id DESC LIMIT ? OFFSET ?"#,
        work_id,
        per_page,
        offset
    )
    .fetch_all(pool.get_ref())
    .await
    .unwrap();

    let total_pages = (total as f64 / per_page as f64).ceil() as i32;

    let template = WorkSubsListTemplate {
        work_subs,
        work_id,
        pagination: Pagination {
            current_page: page,
            per_page,
            total,
            total_pages,
        }
    };
    
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

// 创建工作子项
async fn create_work_sub(
    pool: web::Data<SqlitePool>,
    work_id: web::Path<i64>,
    work_sub_data: web::Form<CreateTWorkSub>,
) -> HttpResponse {
    if work_sub_data.comment.trim().is_empty() {
        let template = ErrorTemplate { 
            message: "コメントは必須です".to_string() 
        };
        return HttpResponse::BadRequest()
            .content_type("text/html")
            .body(template.render().unwrap());
    }

    match sqlx::query!(
        r#"INSERT INTO t_work_sub 
           (work_id, workclass_id, urtime, mtime, durtime, 
            comment, working_user_id, delflg)
           VALUES (?, ?, ?, ?, ?, ?, ?, 0)"#,
        work_id.into_inner(),
        work_sub_data.workclass_id,
        work_sub_data.urtime,
        work_sub_data.mtime,
        work_sub_data.durtime,
        work_sub_data.comment,
        work_sub_data.working_user_id,
    )
    .execute(pool.get_ref())
    .await {
        Ok(_) => work_subs_list(
            pool, 
            work_id, 
            web::Query(PaginationParams { page: Some(1), per_page: Some(10) }))
            .await,
        Err(e) => {
            error!("作業サブ作成失敗: {}", e);
            let template = ErrorTemplate { 
                message: format!("作業サブ作成失敗: {}", e)
            };
            HttpResponse::InternalServerError()
                .content_type("text/html")
                .body(template.render().unwrap())
        }
    }
}

// 更新工作子项
async fn update_work_sub(
    pool: web::Data<SqlitePool>,
    path: web::Path<(i64, i64)>, // (work_id, sub_id)
    work_sub_data: web::Form<UpdateTWorkSub>,
    query: web::Query<PaginationParams>,
) -> impl Responder {
    let (work_id, sub_id) = path.into_inner();
    
    // 获取当前数据
    let current = match sqlx::query_as!(
        TWorkSub,
        r#"SELECT id, work_id, workclass_id, urtime, mtime, durtime, 
                  comment, working_user_id, delflg
           FROM t_work_sub WHERE id = ?"#,
        sub_id
    )
    .fetch_optional(pool.get_ref())
    .await {
        Ok(Some(sub)) => sub,
        Ok(None) => return HttpResponse::NotFound().body("作業サブが見つかりません"),
        Err(e) => {
            error!("作業サブ取得失敗: {}", e);
            return HttpResponse::InternalServerError().body("内部サーバーエラー");
        }
    };
    
    // 确定更新值
    let new_work_id = work_sub_data.work_id.unwrap_or(current.work_id);
    let new_workclass_id = work_sub_data.workclass_id.unwrap_or(current.workclass_id);
    let new_urtime = work_sub_data.urtime.as_ref().or(current.urtime.as_ref());
    let new_mtime = work_sub_data.mtime.as_ref().or(current.mtime.as_ref());
    let new_durtime = work_sub_data.durtime.as_ref().or(current.durtime.as_ref());
    let new_comment = work_sub_data.comment.as_ref().unwrap_or(&current.comment);
    let new_working_user_id = work_sub_data.working_user_id.unwrap_or(current.working_user_id);
    let new_delflg = work_sub_data.delflg.unwrap_or(current.delflg);
    
    match sqlx::query!(
        r#"UPDATE t_work_sub SET 
            work_id = ?, 
            workclass_id = ?, 
            urtime = ?, 
            mtime = ?, 
            durtime = ?, 
            comment = ?, 
            working_user_id = ?, 
            delflg = ?
         WHERE id = ?"#,
        new_work_id,
        new_workclass_id,
        new_urtime,
        new_mtime,
        new_durtime,
        new_comment,
        new_working_user_id,
        new_delflg,
        sub_id,
    )
    .execute(pool.get_ref())
    .await {
        Ok(result) => {
            if result.rows_affected() == 0 {
                return HttpResponse::NotFound().body("作業サブが見つかりません");
            }
            work_subs_list(
                pool, 
                web::Path::from(work_id), 
                query
            ).await
        }
        Err(e) => {
            error!("作業サブ更新失敗: {}", e);
            HttpResponse::InternalServerError().body("作業サブ更新失敗")
        }
    }
}

// 删除工作子项(逻辑删除)
async fn delete_work_sub(
    pool: web::Data<SqlitePool>, 
    path: web::Path<(i64, i64)>,
    query: web::Query<PaginationParams>,
) -> impl Responder {
    let (work_id, sub_id) = path.into_inner();
    
    match sqlx::query!(
        "UPDATE t_work_sub SET delflg = 1 WHERE id = ?",
        sub_id
    )
    .execute(pool.get_ref())
    .await {
        Ok(result) => {
            if result.rows_affected() == 0 {
                return HttpResponse::NotFound().body("作業サブが見つかりません");
            }
            work_subs_list(
                pool, 
                web::Path::from(work_id), 
                query
            ).await
        }
        Err(e) => {
            error!("作業サブ削除失敗: {}", e);
            HttpResponse::InternalServerError().body("作業サブ削除失敗")
        }
    }
}

// 编辑表单
async fn edit_work_sub_form(
    pool: web::Data<SqlitePool>,
    path: web::Path<(i64, i64)>,
) -> HttpResponse {
    let (_, sub_id) = path.into_inner();
    let work_sub = match sqlx::query_as!(
        TWorkSub,
        r#"SELECT id, work_id, workclass_id, urtime, mtime, durtime, 
                  comment, working_user_id, delflg
           FROM t_work_sub WHERE id = ?"#,
        sub_id
    )
    .fetch_optional(pool.get_ref())
    .await {
        Ok(Some(sub)) => sub,
        Ok(None) => return HttpResponse::NotFound().body("作業サブが見つかりません"),
        Err(e) => {
            error!("作業サブ取得失敗: {}", e);
            return HttpResponse::InternalServerError().body("内部サーバーエラー");
        }
    };

    let template = WorkSubsEditTemplate { work_sub };
    HttpResponse::Ok()
        .content_type("text/html")
        .body(template.render().unwrap())
}

// ------------------------------------------------- t_work_sub 处理函数

// 数据库连接池
async fn get_db_pool() -> SqlitePool {
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    info!("Connecting to database at: {}", database_url);
    
    SqlitePool::connect(&database_url).await.unwrap_or_else(|e| {
        error!("Failed to connect to database: {}", e);
        panic!("Failed to connect to database: {}", e);
    })
}

// --------------------------------------------------------- 処理関数

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
    
    info!("Starting Todo application...");

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
            // HTML ルート
            // 
            .route("/users", web::get().to(users_ui))
            .route("/users/list", web::get().to(users_list))
            .route("/users", web::post().to(create_user))
            .route("/users/{id}", web::put().to(update_user))
            .route("/users/{id}", web::delete().to(delete_user))
            .route("/users/{id}/edit", web::get().to(edit_user_form))
            .route("/users/{id}/edit-form", web::get().to(edit_user_form)) // 添加这行
            // 作業ルート
            .route("/works", web::get().to(works_ui))
            .route("/works/list", web::get().to(works_list))
            .route("/works", web::post().to(create_work))
            .route("/works/{id}", web::put().to(update_work))
            .route("/works/{id}", web::delete().to(delete_work))
            .route("/works/{id}/edit-form", web::get().to(edit_work_form))
            // 作業サブ
            .route("/works/{work_id}/subs", web::get().to(work_subs_ui))
            .route("/works/{work_id}/subs/list", web::get().to(work_subs_list))
            .route("/works/{work_id}/subs", web::post().to(create_work_sub))
            .route("/works/{work_id}/subs/{sub_id}", web::put().to(update_work_sub))
            .route("/works/{work_id}/subs/{sub_id}", web::delete().to(delete_work_sub))
            .route("/works/{work_id}/subs/{sub_id}/edit-form", web::get().to(edit_work_sub_form))

    })
    .bind("0.0.0.0:8000")?
    .run()
    .await
}