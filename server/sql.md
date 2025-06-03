该文件 `DbConnectionController.java` 里执行的SQL处理如下（已归类，方便查阅）：

---

### 1. 用户登录相关
```sql
SELECT * FROM m_users WHERE userid = '{uid}' AND passwd = '{pass}' AND delflg=false
```

---

### 2. 客户信息管理
- 检索客户：
```sql
SELECT * FROM m_customers WHERE ({code} Or {name}) AND delflg=false Order By code
```
- 检查客户是否存在（通过名称或代码）：
```sql
SELECT * FROM m_customers WHERE name='{name}'
SELECT * FROM m_customers WHERE code='{code}'
```
- 插入新客户：
```sql
INSERT INTO m_customers (code, name, delflg) values (?, ?, ?)
```
- 获取指定客户：
```sql
SELECT * FROM m_customers WHERE {name} And {code}
```
- 更新客户信息：
```sql
UPDATE m_customers SET name = ?, code = ? WHERE id = ?
```

---

### 3. 工作数据（t_work）相关
- 通过客户ID查找工作：
```sql
SELECT * FROM t_work WHERE customer_id = {customer_id} And delflg=false
```
- 通过ID查找工作：
```sql
SELECT * FROM t_work WHERE id={id}
```
- 通过传票号查找工作：
```sql
SELECT * FROM t_work WHERE slip_number like '%{slip_number}%' And delflg=false Order By slip_number And delflg=false
```
- 多条件查找工作：
```sql
SELECT * FROM t_work WHERE {slip_number and other conditions} And delflg=false
```
- 更新（移档案相关）：
```sql
UPDATE t_work SET folder_id = ? WHERE slip_number='{slip}' And os_id={os_id}
```

---

### 4. 通用Master表信息
- 用户名、版本、工种、OS、服务器、文件夹等信息通过ID获取：
```sql
SELECT * FROM m_users WHERE id={id}
SELECT * FROM m_version WHERE id={id}
SELECT * FROM m_workclass WHERE id={id}
SELECT * FROM m_os WHERE id={id}
SELECT * FROM m_folder WHERE id={id}
```
- 各Master表按条件列举：
```sql
SELECT * FROM m_os Where delflg=false Order By id
SELECT * FROM m_users Where facilitator = 1 AND delflg=false Order By id
SELECT * FROM m_version where delflg=false Order By sort
SELECT * FROM m_folder where delflg=false Order By id
```
- 文件夹相关（含获取ip、path、passwd等）：
```sql
SELECT * FROM m_folder Where id = {id} Order By id
SELECT * FROM m_folder Where id = 4 Or id=5 Order By id
```

---

### 5. 其他
- 获取客户编号：
```sql
SELECT code FROM m_customers Where id = {id} Order By id
```

---

**说明：**
- 大部分SQL是通过字符串拼接生成，部分采用了预编译（PreparedStatement）。
- 变量如 `{uid}`、`{pass}`、`{id}`、`{slip_number}` 代表方法参数或组装的条件内容。
- 建议实际查阅源码确认拼接细节与参数对应关系。

如需对某条SQL的具体用途或调用方法进一步说明，请告知。


# DbConnectionDenpyoController.java 执行的所有SQL处理

---

## t_work_sub 相关

- 插入子任务记录  
  ```sql
  INSERT INTO t_work_sub (work_id, workclass_id, urtime, mtime, durtime, comment, delflg, user, regdate)
  VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)
  ```
- 更新子任务记录  
  ```sql
  UPDATE t_work_sub SET workclass_id=?, urtime=?, mtime=?, durtime=?, comment=?, user=?, regdate=? WHERE id=?
  ```
- 删除子任务记录  
  ```sql
  DELETE FROM t_work_sub WHERE id=?
  ```
- 查询指定工作对应的所有子任务  
  ```sql
  SELECT * FROM t_work_sub WHERE work_id=? AND delflg=false ORDER BY mtime
  ```
- 查询指定子任务  
  ```sql
  SELECT * FROM t_work_sub WHERE id=?
  ```
- 逻辑删除子任务  
  ```sql
  UPDATE t_work_sub SET delflg=true WHERE id=?
  ```

---

## t_work 相关

- 插入工作主记录  
  ```sql
  INSERT INTO t_work (customer_id, slip_number, title, facilitator_id, version_id, os_id, folder_id, delflg)
  VALUES (?, ?, ?, ?, ?, ?, ?, false)
  ```
- 更新工作主记录  
  ```sql
  UPDATE t_work SET customer_id=?, slip_number=?, title=?, facilitator_id=?, version_id=?, os_id=?, folder_id=? WHERE id=?
  ```
- 逻辑删除工作主记录  
  ```sql
  UPDATE t_work SET delflg=true WHERE id=?
  ```
- 查询指定工作主记录  
  ```sql
  SELECT * FROM t_work WHERE id=?
  ```
- 查询指定传票号的工作  
  ```sql
  SELECT * FROM t_work WHERE slip_number=?
  ```
- 查询指定客户的所有工作  
  ```sql
  SELECT * FROM t_work WHERE customer_id=? AND delflg=false
  ```
- 查询所有未删除的工作  
  ```sql
  SELECT * FROM t_work WHERE delflg=false
  ```

---

## t_work_history 相关

- 插入工作历史记录  
  ```sql
  INSERT INTO t_work_history (work_id, action, user, regdate)
  VALUES (?, ?, ?, ?)
  ```
- 查询某工作所有历史记录  
  ```sql
  SELECT * FROM t_work_history WHERE work_id=? ORDER BY id
  ```

---

## 统计与特殊操作

- 查询某传票号的工作数量  
  ```sql
  SELECT COUNT(*) FROM t_work WHERE slip_number=?
  ```
- 删除指定工作ID下所有子任务  
  ```sql
  DELETE FROM t_work_sub WHERE work_id=?
  ```
- 删除指定工作ID下所有历史  
  ```sql
  DELETE FROM t_work_history WHERE work_id=?
  ```
- 删除指定工作主记录  
  ```sql
  DELETE FROM t_work WHERE id=?
  ```
- 查询某工作下所有子任务（无delflg条件）  
  ```sql
  SELECT * FROM t_work_sub WHERE work_id=?
  ```

---

> 注：所有 ? 均为 PreparedStatement 传入参数，实际值由调用代码传递。

# LogWriter.java 执行的SQL处理

---

## 日志写入相关

- 插入日志记录  
  ```sql
  INSERT INTO logs (logdate, message, status) VALUES (?, ?, ?)
  ```

---

> 注：所有 `?` 为 PreparedStatement 传入参数，实际值由调用代码传递。

如需具体SQL语句所在方法或更多细节，请补充说明。