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