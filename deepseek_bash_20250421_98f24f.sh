#!/bin/bash

# Create project directory structure
mkdir -p tanaka-web/{src/{models,routes,templates/{work,work_sub,customers,folder,os,users,version,workclass,logs}},migrations,static}

# Generate Cargo.toml
cat > tanaka-web/Cargo.toml << 'EOL'
[package]
name = "tanaka-web"
version = "0.1.0"
edition = "2021"

[dependencies]
actix-web = "4.0"
actix-rt = "2.0"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
rusqlite = { version = "0.28.0", features = ["bundled"] }
askama = "0.11"
htmx = "0.3"
lazy_static = "1.4"
chrono = { version = "0.4", features = ["serde"] }
actix-files = "0.6"
EOL

# Generate db.rs
cat > tanaka-web/src/db.rs << 'EOL'
use rusqlite::{Connection, Result};
use std::sync::Mutex;

lazy_static::lazy_static! {
    static ref DB_CONNECTION: Mutex<Connection> = {
        let conn = Connection::open("database.db").expect("Failed to open database");
        conn.execute("PRAGMA foreign_keys = ON", [])
            .expect("Failed to enable foreign keys");
        Mutex::new(conn)
    };
}

pub fn get_connection() -> Result<std::sync::MutexGuard<'static, Connection>> {
    Ok(DB_CONNECTION.lock().unwrap())
}
EOL

# Generate models.rs
cat > tanaka-web/src/models.rs << 'EOL'
use serde::{Deserialize, Serialize};
use rusqlite::{params, Result};
use chrono::{DateTime, Utc};

#[derive(Debug, Serialize, Deserialize)]
pub struct Work {
    pub id: i32,
    pub customer_id: i32,
    pub slip_number: String,
    pub title: String,
    pub facilitator_id: String,
    pub version_id: i32,
    pub os_id: i32,
    pub folder_id: i32,
    pub delflg: i32,
    pub mountflg: i32,
    pub mountflgstr: Option<String>,
}

impl Work {
    pub fn create(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "INSERT INTO t_work (customer_id, slip_number, title, facilitator_id, version_id, os_id, folder_id, delflg, mountflg, mountflgstr) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
            params![
                self.customer_id,
                self.slip_number,
                self.title,
                self.facilitator_id,
                self.version_id,
                self.os_id,
                self.folder_id,
                self.delflg,
                self.mountflg,
                self.mountflgstr
            ],
        )?;
        Ok(())
    }

    pub fn get_all() -> Result<Vec<Self>> {
        let conn = crate::db::get_connection()?;
        let mut stmt = conn.prepare("SELECT id, customer_id, slip_number, title, facilitator_id, version_id, os_id, folder_id, delflg, mountflg, mountflgstr FROM t_work WHERE delflg = 0")?;
        let works = stmt.query_map([], |row| {
            Ok(Self {
                id: row.get(0)?,
                customer_id: row.get(1)?,
                slip_number: row.get(2)?,
                title: row.get(3)?,
                facilitator_id: row.get(4)?,
                version_id: row.get(5)?,
                os_id: row.get(6)?,
                folder_id: row.get(7)?,
                delflg: row.get(8)?,
                mountflg: row.get(9)?,
                mountflgstr: row.get(10)?,
            })
        })?.collect::<Result<Vec<_>>>()?;
        Ok(works)
    }

    pub fn get_by_id(id: i32) -> Result<Self> {
        let conn = crate::db::get_connection()?;
        conn.query_row(
            "SELECT id, customer_id, slip_number, title, facilitator_id, version_id, os_id, folder_id, delflg, mountflg, mountflgstr FROM t_work WHERE id = ?1",
            [id],
            |row| {
                Ok(Self {
                    id: row.get(0)?,
                    customer_id: row.get(1)?,
                    slip_number: row.get(2)?,
                    title: row.get(3)?,
                    facilitator_id: row.get(4)?,
                    version_id: row.get(5)?,
                    os_id: row.get(6)?,
                    folder_id: row.get(7)?,
                    delflg: row.get(8)?,
                    mountflg: row.get(9)?,
                    mountflgstr: row.get(10)?,
                })
            },
        )
    }

    pub fn update(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE t_work SET customer_id = ?1, slip_number = ?2, title = ?3, facilitator_id = ?4, version_id = ?5, os_id = ?6, folder_id = ?7, delflg = ?8, mountflg = ?9, mountflgstr = ?10 WHERE id = ?11",
            params![
                self.customer_id,
                self.slip_number,
                self.title,
                self.facilitator_id,
                self.version_id,
                self.os_id,
                self.folder_id,
                self.delflg,
                self.mountflg,
                self.mountflgstr,
                self.id
            ],
        )?;
        Ok(())
    }

    pub fn delete(id: i32) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE t_work SET delflg = 1 WHERE id = ?1",
            [id],
        )?;
        Ok(())
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct WorkSub {
    pub id: i32,
    pub work_id: i32,
    pub workclass_id: i32,
    pub urtime: Option<String>,
    pub mtime: Option<String>,
    pub durtime: Option<String>,
    pub comment: String,
    pub working_user_id: i32,
    pub delflg: i32,
}

impl WorkSub {
    pub fn create(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "INSERT INTO t_work_sub (work_id, workclass_id, urtime, mtime, durtime, comment, working_user_id, delflg) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![
                self.work_id,
                self.workclass_id,
                self.urtime,
                self.mtime,
                self.durtime,
                self.comment,
                self.working_user_id,
                self.delflg
            ],
        )?;
        Ok(())
    }

    pub fn get_all() -> Result<Vec<Self>> {
        let conn = crate::db::get_connection()?;
        let mut stmt = conn.prepare("SELECT id, work_id, workclass_id, urtime, mtime, durtime, comment, working_user_id, delflg FROM t_work_sub WHERE delflg = 0")?;
        let work_subs = stmt.query_map([], |row| {
            Ok(Self {
                id: row.get(0)?,
                work_id: row.get(1)?,
                workclass_id: row.get(2)?,
                urtime: row.get(3)?,
                mtime: row.get(4)?,
                durtime: row.get(5)?,
                comment: row.get(6)?,
                working_user_id: row.get(7)?,
                delflg: row.get(8)?,
            })
        })?.collect::<Result<Vec<_>>>()?;
        Ok(work_subs)
    }

    pub fn get_by_id(id: i32) -> Result<Self> {
        let conn = crate::db::get_connection()?;
        conn.query_row(
            "SELECT id, work_id, workclass_id, urtime, mtime, durtime, comment, working_user_id, delflg FROM t_work_sub WHERE id = ?1",
            [id],
            |row| {
                Ok(Self {
                    id: row.get(0)?,
                    work_id: row.get(1)?,
                    workclass_id: row.get(2)?,
                    urtime: row.get(3)?,
                    mtime: row.get(4)?,
                    durtime: row.get(5)?,
                    comment: row.get(6)?,
                    working_user_id: row.get(7)?,
                    delflg: row.get(8)?,
                })
            },
        )
    }

    pub fn update(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE t_work_sub SET work_id = ?1, workclass_id = ?2, urtime = ?3, mtime = ?4, durtime = ?5, comment = ?6, working_user_id = ?7, delflg = ?8 WHERE id = ?9",
            params![
                self.work_id,
                self.workclass_id,
                self.urtime,
                self.mtime,
                self.durtime,
                self.comment,
                self.working_user_id,
                self.delflg,
                self.id
            ],
        )?;
        Ok(())
    }

    pub fn delete(id: i32) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE t_work_sub SET delflg = 1 WHERE id = ?1",
            [id],
        )?;
        Ok(())
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Customer {
    pub id: i32,
    pub code: String,
    pub name: String,
    pub delflg: i32,
}

impl Customer {
    pub fn create(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "INSERT INTO m_customers (code, name, delflg) VALUES (?1, ?2, ?3)",
            params![self.code, self.name, self.delflg],
        )?;
        Ok(())
    }

    pub fn get_all() -> Result<Vec<Self>> {
        let conn = crate::db::get_connection()?;
        let mut stmt = conn.prepare("SELECT id, code, name, delflg FROM m_customers WHERE delflg = 0")?;
        let customers = stmt.query_map([], |row| {
            Ok(Self {
                id: row.get(0)?,
                code: row.get(1)?,
                name: row.get(2)?,
                delflg: row.get(3)?,
            })
        })?.collect::<Result<Vec<_>>>()?;
        Ok(customers)
    }

    pub fn get_by_id(id: i32) -> Result<Self> {
        let conn = crate::db::get_connection()?;
        conn.query_row(
            "SELECT id, code, name, delflg FROM m_customers WHERE id = ?1",
            [id],
            |row| {
                Ok(Self {
                    id: row.get(0)?,
                    code: row.get(1)?,
                    name: row.get(2)?,
                    delflg: row.get(3)?,
                })
            },
        )
    }

    pub fn update(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE m_customers SET code = ?1, name = ?2, delflg = ?3 WHERE id = ?4",
            params![self.code, self.name, self.delflg, self.id],
        )?;
        Ok(())
    }

    pub fn delete(id: i32) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE m_customers SET delflg = 1 WHERE id = ?1",
            [id],
        )?;
        Ok(())
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Folder {
    pub id: i32,
    pub name: String,
    pub ip: String,
    pub path: String,
    pub admin: i32,
    pub user_name: String,
    pub passwd: String,
    pub delflg: i32,
}

impl Folder {
    pub fn create(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "INSERT INTO m_folder (name, ip, path, admin, user_name, passwd, delflg) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                self.name,
                self.ip,
                self.path,
                self.admin,
                self.user_name,
                self.passwd,
                self.delflg
            ],
        )?;
        Ok(())
    }

    pub fn get_all() -> Result<Vec<Self>> {
        let conn = crate::db::get_connection()?;
        let mut stmt = conn.prepare("SELECT id, name, ip, path, admin, user_name, passwd, delflg FROM m_folder WHERE delflg = 0")?;
        let folders = stmt.query_map([], |row| {
            Ok(Self {
                id: row.get(0)?,
                name: row.get(1)?,
                ip: row.get(2)?,
                path: row.get(3)?,
                admin: row.get(4)?,
                user_name: row.get(5)?,
                passwd: row.get(6)?,
                delflg: row.get(7)?,
            })
        })?.collect::<Result<Vec<_>>>()?;
        Ok(folders)
    }

    pub fn get_by_id(id: i32) -> Result<Self> {
        let conn = crate::db::get_connection()?;
        conn.query_row(
            "SELECT id, name, ip, path, admin, user_name, passwd, delflg FROM m_folder WHERE id = ?1",
            [id],
            |row| {
                Ok(Self {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    ip: row.get(2)?,
                    path: row.get(3)?,
                    admin: row.get(4)?,
                    user_name: row.get(5)?,
                    passwd: row.get(6)?,
                    delflg: row.get(7)?,
                })
            },
        )
    }

    pub fn update(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE m_folder SET name = ?1, ip = ?2, path = ?3, admin = ?4, user_name = ?5, passwd = ?6, delflg = ?7 WHERE id = ?8",
            params![
                self.name,
                self.ip,
                self.path,
                self.admin,
                self.user_name,
                self.passwd,
                self.delflg,
                self.id
            ],
        )?;
        Ok(())
    }

    pub fn delete(id: i32) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE m_folder SET delflg = 1 WHERE id = ?1",
            [id],
        )?;
        Ok(())
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct OS {
    pub id: i32,
    pub name: String,
    pub comment: String,
    pub delflg: i32,
}

impl OS {
    pub fn create(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "INSERT INTO m_os (name, comment, delflg) VALUES (?1, ?2, ?3)",
            params![self.name, self.comment, self.delflg],
        )?;
        Ok(())
    }

    pub fn get_all() -> Result<Vec<Self>> {
        let conn = crate::db::get_connection()?;
        let mut stmt = conn.prepare("SELECT id, name, comment, delflg FROM m_os WHERE delflg = 0")?;
        let os_list = stmt.query_map([], |row| {
            Ok(Self {
                id: row.get(0)?,
                name: row.get(1)?,
                comment: row.get(2)?,
                delflg: row.get(3)?,
            })
        })?.collect::<Result<Vec<_>>>()?;
        Ok(os_list)
    }

    pub fn get_by_id(id: i32) -> Result<Self> {
        let conn = crate::db::get_connection()?;
        conn.query_row(
            "SELECT id, name, comment, delflg FROM m_os WHERE id = ?1",
            [id],
            |row| {
                Ok(Self {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    comment: row.get(2)?,
                    delflg: row.get(3)?,
                })
            },
        )
    }

    pub fn update(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE m_os SET name = ?1, comment = ?2, delflg = ?3 WHERE id = ?4",
            params![self.name, self.comment, self.delflg, self.id],
        )?;
        Ok(())
    }

    pub fn delete(id: i32) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE m_os SET delflg = 1 WHERE id = ?1",
            [id],
        )?;
        Ok(())
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct User {
    pub id: i32,
    pub userid: String,
    pub passwd: String,
    pub fname: String,
    pub lname: String,
    pub permission: i32,
    pub facilitator: i32,
    pub delflg: i32,
}

impl User {
    pub fn create(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "INSERT INTO m_users (userid, passwd, fname, lname, permission, facilitator, delflg) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                self.userid,
                self.passwd,
                self.fname,
                self.lname,
                self.permission,
                self.facilitator,
                self.delflg
            ],
        )?;
        Ok(())
    }

    pub fn get_all() -> Result<Vec<Self>> {
        let conn = crate::db::get_connection()?;
        let mut stmt = conn.prepare("SELECT id, userid, passwd, fname, lname, permission, facilitator, delflg FROM m_users WHERE delflg = 0")?;
        let users = stmt.query_map([], |row| {
            Ok(Self {
                id: row.get(0)?,
                userid: row.get(1)?,
                passwd: row.get(2)?,
                fname: row.get(3)?,
                lname: row.get(4)?,
                permission: row.get(5)?,
                facilitator: row.get(6)?,
                delflg: row.get(7)?,
            })
        })?.collect::<Result<Vec<_>>>()?;
        Ok(users)
    }

    pub fn get_by_id(id: i32) -> Result<Self> {
        let conn = crate::db::get_connection()?;
        conn.query_row(
            "SELECT id, userid, passwd, fname, lname, permission, facilitator, delflg FROM m_users WHERE id = ?1",
            [id],
            |row| {
                Ok(Self {
                    id: row.get(0)?,
                    userid: row.get(1)?,
                    passwd: row.get(2)?,
                    fname: row.get(3)?,
                    lname: row.get(4)?,
                    permission: row.get(5)?,
                    facilitator: row.get(6)?,
                    delflg: row.get(7)?,
                })
            },
        )
    }

    pub fn update(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE m_users SET userid = ?1, passwd = ?2, fname = ?3, lname = ?4, permission = ?5, facilitator = ?6, delflg = ?7 WHERE id = ?8",
            params![
                self.userid,
                self.passwd,
                self.fname,
                self.lname,
                self.permission,
                self.facilitator,
                self.delflg,
                self.id
            ],
        )?;
        Ok(())
    }

    pub fn delete(id: i32) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE m_users SET delflg = 1 WHERE id = ?1",
            [id],
        )?;
        Ok(())
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Version {
    pub id: i32,
    pub name: String,
    pub comment: String,
    pub delflg: i32,
    pub sort: i32,
}

impl Version {
    pub fn create(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "INSERT INTO m_version (name, comment, delflg, sort) VALUES (?1, ?2, ?3, ?4)",
            params![self.name, self.comment, self.delflg, self.sort],
        )?;
        Ok(())
    }

    pub fn get_all() -> Result<Vec<Self>> {
        let conn = crate::db::get_connection()?;
        let mut stmt = conn.prepare("SELECT id, name, comment, delflg, sort FROM m_version WHERE delflg = 0 ORDER BY sort")?;
        let versions = stmt.query_map([], |row| {
            Ok(Self {
                id: row.get(0)?,
                name: row.get(1)?,
                comment: row.get(2)?,
                delflg: row.get(3)?,
                sort: row.get(4)?,
            })
        })?.collect::<Result<Vec<_>>>()?;
        Ok(versions)
    }

    pub fn get_by_id(id: i32) -> Result<Self> {
        let conn = crate::db::get_connection()?;
        conn.query_row(
            "SELECT id, name, comment, delflg, sort FROM m_version WHERE id = ?1",
            [id],
            |row| {
                Ok(Self {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    comment: row.get(2)?,
                    delflg: row.get(3)?,
                    sort: row.get(4)?,
                })
            },
        )
    }

    pub fn update(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE m_version SET name = ?1, comment = ?2, delflg = ?3, sort = ?4 WHERE id = ?5",
            params![self.name, self.comment, self.delflg, self.sort, self.id],
        )?;
        Ok(())
    }

    pub fn delete(id: i32) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE m_version SET delflg = 1 WHERE id = ?1",
            [id],
        )?;
        Ok(())
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct WorkClass {
    pub id: i32,
    pub name: String,
    pub comment: String,
}

impl WorkClass {
    pub fn create(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "INSERT INTO m_workclass (id, name, comment) VALUES (?1, ?2, ?3)",
            params![self.id, self.name, self.comment],
        )?;
        Ok(())
    }

    pub fn get_all() -> Result<Vec<Self>> {
        let conn = crate::db::get_connection()?;
        let mut stmt = conn.prepare("SELECT id, name, comment FROM m_workclass")?;
        let workclasses = stmt.query_map([], |row| {
            Ok(Self {
                id: row.get(0)?,
                name: row.get(1)?,
                comment: row.get(2)?,
            })
        })?.collect::<Result<Vec<_>>>()?;
        Ok(workclasses)
    }

    pub fn get_by_id(id: i32) -> Result<Self> {
        let conn = crate::db::get_connection()?;
        conn.query_row(
            "SELECT id, name, comment FROM m_workclass WHERE id = ?1",
            [id],
            |row| {
                Ok(Self {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    comment: row.get(2)?,
                })
            },
        )
    }

    pub fn update(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "UPDATE m_workclass SET name = ?1, comment = ?2 WHERE id = ?3",
            params![self.name, self.comment, self.id],
        )?;
        Ok(())
    }

    pub fn delete(id: i32) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "DELETE FROM m_workclass WHERE id = ?1",
            [id],
        )?;
        Ok(())
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Log {
    pub id: i32,
    pub user_id: Option<i32>,
    pub user_name: Option<String>,
    pub folder_name: Option<String>,
    pub work_content: Option<String>,
    pub result: Option<String>,
    pub created: String,
}

impl Log {
    pub fn create(&self) -> Result<()> {
        let conn = crate::db::get_connection()?;
        conn.execute(
            "INSERT INTO t_logs (user_id, user_name, folder_name, work_content, result) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![
                self.user_id,
                self.user_name,
                self.folder_name,
                self.work_content,
                self.result
            ],
        )?;
        Ok(())
    }

    pub fn get_all() -> Result<Vec<Self>> {
        let conn = crate::db::get_connection()?;
        let mut stmt = conn.prepare("SELECT id, user_id, user_name, folder_name, work_content, result, created FROM t_logs ORDER BY created DESC")?;
        let logs = stmt.query_map([], |row| {
            Ok(Self {
                id: row.get(0)?,
                user_id: row.get(1)?,
                user_name: row.get(2)?,
                folder_name: row.get(3)?,
                work_content: row.get(4)?,
                result: row.get(5)?,
                created: row.get(6)?,
            })
        })?.collect::<Result<Vec<_>>>()?;
        Ok(logs)
    }

    pub fn get_by_id(id: i32) -> Result<Self> {
        let conn = crate::db::get_connection()?;
        conn.query_row(
            "SELECT id, user_id, user_name, folder_name, work_content, result, created FROM t_logs WHERE id = ?1",
            [id],
            |row| {
                Ok(Self {
                    id: row.get(0)?,
                    user_id: row.get(1)?,
                    user_name: row.get(2)?,
                    folder_name: row.get(3)?,
                    work_content: row.get(4)?,
                    result: row.get(5)?,
                    created: row.get(6)?,
                })
            },
        )
    }
}
EOL

# Generate routes.rs
cat > tanaka-web/src/routes.rs << 'EOL'
use actix_web::{web, HttpResponse, Responder};
use askama::Template;
use serde::{Deserialize, Serialize};

use crate::models::{Work, WorkSub, Customer, Folder, OS, User, Version, WorkClass, Log};

// Work routes

#[derive(Template)]
#[template(path = "work/list.html")]
struct WorkListTemplate {
    works: Vec<Work>,
    customers: Vec<Customer>,
    versions: Vec<Version>,
    os_list: Vec<OS>,
    folders: Vec<Folder>,
}

pub async fn list_works() -> impl Responder {
    match (Work::get_all(), Customer::get_all(), Version::get_all(), OS::get_all(), Folder::get_all()) {
        (Ok(works), Ok(customers), Ok(versions), Ok(os_list), Ok(folders)) => {
            let template = WorkListTemplate {
                works,
                customers,
                versions,
                os_list,
                folders,
            };
            HttpResponse::Ok().body(template.render().unwrap())
        }
        _ => HttpResponse::InternalServerError().body("Error loading data"),
    }
}

#[derive(Deserialize)]
pub struct CreateWorkForm {
    customer_id: i32,
    slip_number: String,
    title: String,
    facilitator_id: String,
    version_id: i32,
    os_id: i32,
    folder_id: i32,
}

pub async fn create_work(form: web::Form<CreateWorkForm>) -> impl Responder {
    let work = Work {
        id: 0,
        customer_id: form.customer_id,
        slip_number: form.slip_number.clone(),
        title: form.title.clone(),
        facilitator_id: form.facilitator_id.clone(),
        version_id: form.version_id,
        os_id: form.os_id,
        folder_id: form.folder_id,
        delflg: 0,
        mountflg: 0,
        mountflgstr: None,
    };

    match work.create() {
        Ok(_) => HttpResponse::Ok().body("Work created successfully"),
        Err(e) => HttpResponse::InternalServerError().body(format!("Error: {}", e)),
    }
}

#[derive(Template)]
#[template(path = "work/edit.html")]
struct WorkEditTemplate {
    work: Work,
    customers: Vec<Customer>,
    versions: Vec<Version>,
    os_list: Vec<OS>,
    folders: Vec<Folder>,
}

pub async fn edit_work(work_id: web::Path<i32>) -> impl Responder {
    match (Work::get_by_id(work_id.into_inner()), Customer::get_all(), Version::get_all(), OS::get_all(), Folder::get_all()) {
        (Ok(work), Ok(customers), Ok(versions), Ok(os_list), Ok(folders)) => {
            let template = WorkEditTemplate {
                work,
                customers,
                versions,
                os_list,
                folders,
            };
            HttpResponse::Ok().body(template.render().unwrap())
        }
        _ => HttpResponse::InternalServerError().body("Error loading data"),
    }
}

#[derive(Deserialize)]
pub struct UpdateWorkForm {
    id: i32,
    customer_id: i32,
    slip_number: String,
    title: String,
    facilitator_id: String,
    version_id: i32,
    os_id: i32,
    folder_id: i32,
}

pub async fn update_work(form: web::Form<UpdateWorkForm>) -> impl Responder {
    let work = Work {
        id: form.id,
        customer_id: form.customer_id,
        slip_number: form.slip_number.clone(),
        title: form.title.clone(),
        facilitator_id: form.facilitator_id.clone(),
        version_id: form.version_id,
        os_id: form.os_id,
        folder_id: form.folder_id,
        delflg: 0,
        mountflg: 0,
        mountflgstr: None,
    };

    match work.update() {
        Ok(_) => HttpResponse::Ok().body("Work updated successfully"),
        Err(e) => HttpResponse::InternalServerError().body(format!("Error: {}", e)),
    }
}

pub async fn delete_work(work_id: web::Path<i32>) -> impl Responder {
    match Work::delete(work_id.into_inner()) {
        Ok(_) => HttpResponse::Ok().body("Work deleted successfully"),
        Err(e) => HttpResponse::InternalServerError().body(format!("Error: {}", e)),
    }
}

// Similar route implementations for other models (WorkSub, Customer, Folder, OS, User, Version, WorkClass, Log)
EOL

# Generate main.rs
cat > tanaka-web/src/main.rs << 'EOL'
mod db;
mod models;
mod routes;
mod templates;

use actix_web::{App, HttpServer, web};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize database
    db::get_connection().expect("Failed to initialize database");

    HttpServer::new(|| {
        App::new()
            .service(
                web::resource("/works")
                    .route(web::get().to(routes::list_works))
            )
            .service(
                web::resource("/works/create")
                    .route(web::post().to(routes::create_work))
            )
            .service(
                web::resource("/works/{id}/edit")
                    .route(web::get().to(routes::edit_work))
            )
            .service(
                web::resource("/works/{id}/update")
                    .route(web::post().to(routes::update_work))
            )
            .service(
                web::resource("/works/{id}/delete")
                    .route(web::post().to(routes::delete_work))
            )
            // Add similar routes for other models
            .service(actix_files::Files::new("/static", "static"))
    })
    .bind("127.0.0.1:8080")?
    .run()
    .await
}
EOL

# Generate work list template
mkdir -p tanaka-web/src/templates/work
cat > tanaka-web/src/templates/work/list.html << 'EOL'
<!DOCTYPE html>
<html lang="en" hx-boost="true">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Works</title>
    <script src="https://unpkg.com/htmx.org@1.9.0"></script>
    <link rel="stylesheet" href="/static/style.css">
</head>
<body>
    <h1>Works</h1>
    
    <div id="work-list">
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Slip Number</th>
                    <th>Title</th>
                    <th>Customer</th>
                    <th>Facilitator</th>
                    <th>Version</th>
                    <th>OS</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                {% for work in works %}
                <tr>
                    <td>{{ work.id }}</td>
                    <td>{{ work.slip_number }}</td>
                    <td>{{ work.title }}</td>
                    <td>{{ work.customer_id }}</td>
                    <td>{{ work.facilitator_id }}</td>
                    <td>{{ work.version_id }}</td>
                    <td>{{ work.os_id }}</td>
                    <td>
                        <a href="/works/{{ work.id }}/edit" hx-get="/works/{{ work.id }}/edit" hx-target="#edit-form">Edit</a>
                        <button hx-delete="/works/{{ work.id }}/delete" hx-confirm="Are you sure you want to delete this work?">Delete</button>
                    </td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
    </div>

    <div id="create-form">
        <h2>Create New Work</h2>
        <form hx-post="/works/create" hx-target="#work-list" hx-swap="outerHTML">
            <div>
                <label for="customer_id">Customer:</label>
                <select name="customer_id" required>
                    {% for customer in customers %}
                    <option value="{{ customer.id }}">{{ customer.name }}</option>
                    {% endfor %}
                </select>
            </div>
            
            <div>
                <label for="slip_number">Slip Number:</label>
                <input type="text" name="slip_number" required>
            </div>
            
            <div>
                <label for="title">Title:</label>
                <input type="text" name="title" required>
            </div>
            
            <div>
                <label for="facilitator_id">Facilitator ID:</label>
                <input type="text" name="facilitator_id" required>
            </div>
            
            <div>
                <label for="version_id">Version:</label>
                <select name="version_id" required>
                    {% for version in versions %}
                    <option value="{{ version.id }}">{{ version.name }}</option>
                    {% endfor %}
                </select>
            </div>
            
            <div>
                <label for="os_id">OS:</label>
                <select name="os_id" required>
                    {% for os in os_list %}
                    <option value="{{ os.id }}">{{ os.name }}</option>
                    {% endfor %}
                </select>
            </div>
            
            <div>
                <label for="folder_id">Folder:</label>
                <select name="folder_id" required>
                    {% for folder in folders %}
                    <option value="{{ folder.id }}">{{ folder.name }}</option>
                    {% endfor %}
                </select>
            </div>
            
            <button type="submit">Create</button>
        </form>
    </div>

    <div id="edit-form"></div>
</body>
</html>
EOL

# Generate work edit template
cat > tanaka-web/src/templates/work/edit.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Edit Work</title>
</head>
<body>
    <h1>Edit Work</h1>
    
    <form hx-put="/works/{{ work.id }}/update" hx-target="body">
        <input type="hidden" name="id" value="{{ work.id }}">
        
        <div>
            <label for="customer_id">Customer:</label>
            <select name="customer_id" required>
                {% for customer in customers %}
                <option value="{{ customer.id }}" {% if customer.id == work.customer_id %}selected{% endif %}>{{ customer.name }}</option>
                {% endfor %}
            </select>
        </div>
        
        <div>
            <label for="slip_number">Slip Number:</label>
            <input type="text" name="slip_number" value="{{ work.slip_number }}" required>
        </div>
        
        <div>
            <label for="title">Title:</label>
            <input type="text" name="title" value="{{ work.title }}" required>
        </div>
        
        <div>
            <label for="facilitator_id">Facilitator ID:</label>
            <input type="text" name="facilitator_id" value="{{ work.facilitator_id }}" required>
        </div>
        
        <div>
            <label for="version_id">Version:</label>
            <select name="version_id" required>
                {% for version in versions %}
                <option value="{{ version.id }}" {% if version.id == work.version_id %}selected{% endif %}>{{ version.name }}</option>
                {% endfor %}
            </select>
        </div>
        
        <div>
            <label for="os_id">OS:</label>
            <select name="os_id" required>
                {% for os in os_list %}
                <option value="{{ os.id }}" {% if os.id == work.os_id %}selected{% endif %}>{{ os.name }}</option>
                {% endfor %}
            </select>
        </div>
        
        <div>
            <label for="folder_id">Folder:</label>
            <select name="folder_id" required>
                {% for folder in folders %}
                <option value="{{ folder.id }}" {% if folder.id == work.folder_id %}selected{% endif %}>{{ folder.name }}</option>
                {% endfor %}
            </select>
        </div>
        
        <button type="submit">Update</button>
        <a href="/works">Cancel</a>
    </form>
</body>
</html>
EOL

# Generate basic CSS
cat > tanaka-web/static/style.css << 'EOL'
body {
    font-family: Arial, sans-serif;
    margin: 20px;
    line-height: 1.6;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 20px;
}

th, td {
    border: 1px solid #ddd;
    padding: 8px;
    text-align: left;
}

th {
    background-color: #f2f2f2;
}

tr:nth-child(even) {
    background-color: #f9f9f9;
}

form div {
    margin-bottom: 10px;
}

label {
    display: inline-block;
    width: 150px;
}

input, select {
    padding: 5px;
    width: 200px;
}

button, a {
    padding: 5px 10px;
    margin-right: 5px;
    text-decoration: none;
    color: #333;
    background-color: #eee;
    border: 1px solid #ccc;
    cursor: pointer;
}

button:hover, a:hover {
    background-color: #ddd;
}
EOL

# Generate migration file
cat > tanaka-web/migrations/0001_initial.sql << 'EOL'
-- Migration based on the provided MariaDB schema, adapted for SQLite

CREATE TABLE t_work (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER NOT NULL,
    slip_number TEXT NOT NULL,
    title TEXT NOT NULL,
    facilitator_id TEXT NOT NULL,
    version_id INTEGER NOT NULL,
    os_id INTEGER NOT NULL,
    folder_id INTEGER NOT NULL,
    delflg INTEGER NOT NULL DEFAULT 0,
    mountflg INTEGER NOT NULL DEFAULT 0,
    mountflgstr TEXT
);

CREATE TABLE t_work_sub (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    work_id INTEGER NOT NULL,
    workclass_id INTEGER NOT NULL,
    urtime TEXT,
    mtime TEXT,
    durtime TEXT,
    comment TEXT NOT NULL,
    working_user_id INTEGER NOT NULL,
    delflg INTEGER NOT NULL,
    FOREIGN KEY (work_id) REFERENCES t_work(id)
);

CREATE TABLE m_customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    delflg INTEGER NOT NULL
);

CREATE TABLE m_folder (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    ip TEXT NOT NULL,
    path TEXT NOT NULL,
    admin INTEGER NOT NULL,
    user_name TEXT NOT NULL,
    passwd TEXT NOT NULL,
    delflg INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE m_os (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    comment TEXT NOT NULL,
    delflg INTEGER NOT NULL DEFAULT 0
);

INSERT INTO m_os (name, comment, delflg) VALUES 
('Win', 'windows', 0),
('Mac', 'macosx', 0),
('Automatic', '自動処理', 0);

CREATE TABLE m_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userid TEXT NOT NULL,
    passwd TEXT NOT NULL,
    fname TEXT NOT NULL,
    lname TEXT NOT NULL,
    permission INTEGER NOT NULL,
    facilitator INTEGER NOT NULL,
    delflg INTEGER NOT NULL
);

CREATE TABLE m_version (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    comment TEXT NOT NULL,
    delflg INTEGER NOT NULL DEFAULT 0,
    sort INTEGER NOT NULL
);

CREATE TABLE m_workclass (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    comment TEXT NOT NULL
);

CREATE TABLE t_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    user_name TEXT,
    folder_name TEXT,
    work_content TEXT,
    result TEXT,
    created TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
EOL

# Make the script executable
chmod +x generate_rust_app.sh

echo "Rust application code generation complete!"
echo "To set up and run the application:"
echo "1. cd tanaka-web"
echo "2. cargo build"
echo "3. sqlite3 database.db < migrations/0001_initial.sql"
echo "4. cargo run"