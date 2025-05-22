
PRAGMA foreign_keys = ON;

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
  urtime DATETIME,
  mtime DATETIME,
  durtime DATETIME,
  comment TEXT NOT NULL,
  working_user_id INTEGER NOT NULL,
  delflg INTEGER NOT NULL
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

INSERT INTO m_os (id, name, comment, delflg) VALUES
  (1, 'Win', 'windows', 0),
  (2, 'Mac', 'macosx', 0),
  (4, '自動処理', 'Windows', 1),
  (5, 'Automatic', '自動処理', 0);

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
  created TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
