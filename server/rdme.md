✅ **可以做到你不用为每个表写模型代码**（`models/xxx.py`），只写 YAML 配置文件，也能实现完整的 CRUD 功能，包括视图支持。

这就是完全“**YAML 驱动建模**”的思路，下面我来给你写出可运行结构：

---

# ✅ 思路：动态模型生成 = 利用 `type()` + SQLAlchemy + YAML 配置

---

## ✅ 1. YAML 定义表结构（你已有）

**示例：`app/config/models/m_users.yaml`**

```yaml
model:
  name: MUsers
  table_name: m_users
  route_prefix: master
  fields:
    userid:
      type: String(50)
      primary_key: true
      label: ユーザーID
    fname:
      type: String(50)
      label: 名
    lname:
      type: String(50)
      label: 姓
```

---

## ✅ 2. 动态构建模型类

**文件**：`app/models/__init__.py` 中动态创建模型（无需单独写每个 `models/*.py`）

```python
import os, yaml
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean
from app.core.base_model import BaseModel
from app.db import engine
from typing import Dict

model_registry: Dict[str, BaseModel] = {}

TYPE_MAP = {
    "Integer": Integer,
    "String": String,
    "Float": Float,
    "Boolean": Boolean,
    "DateTime": DateTime,
}

def load_yaml_models():
    config_dir = "app/config/models"
    for filename in os.listdir(config_dir):
        if not filename.endswith(".yaml"):
            continue
        with open(os.path.join(config_dir, filename), "r", encoding="utf-8") as f:
            cfg = yaml.safe_load(f)

        model_info = cfg["model"]
        class_name = model_info["name"]
        table_name = model_info["table_name"]
        fields = model_info["fields"]

        attrs = {
            "__tablename__": table_name,
        }

        if model_info.get("is_view"):
            attrs["__is_view__"] = True

        for name, field in fields.items():
            ftype = field["type"]
            # 支持 String(50)
            if "String" in ftype and "(" in ftype:
                base, length = ftype.replace(")", "").split("(")
                coltype = String(int(length))
            else:
                coltype = TYPE_MAP[ftype]()

            kwargs = {}
            if field.get("primary_key"):
                kwargs["primary_key"] = True
            if not field.get("required", True):
                kwargs["nullable"] = True

            attrs[name] = Column(coltype, **kwargs)

        cls = type(class_name, (BaseModel,), attrs)
        model_registry[class_name] = cls
```

---

## ✅ 3. 初始化时调用动态注册

在 `app/models/__init__.py` 中添加：

```python
load_yaml_models()
```

> ✅ 这样运行时自动注册所有模型，FastAPI 中无需静态定义模型类！

---

## ✅ 4. 在路由注册中引用这些模型

**文件**：`app/routers/__init__.py`

```python
from fastapi import APIRouter
from app.models import model_registry
from app.core.base_crud import BaseCRUD

router = APIRouter()

for model in model_registry.values():
    if getattr(model, "__is_view__", False) and not getattr(model, "allow_edit", False):
        continue
    router.include_router(BaseCRUD.create_router(model))
```

---

# ✅ 最终效果

| 你写的内容               | 系统生成的内容                |
| ------------------- | ---------------------- |
| ✅ 只写 YAML           | ✅ 自动创建 SQLAlchemy 模型   |
| 不写 `models/*.py`    | ✅ 自动生成类、字段、主键          |
| ✅ 不写 `routers/*.py` | ✅ 自动注册 CRUD 路由         |
| ✅ 不写模板也可以           | ✅ 可生成 form/list/detail |

---

## ✅ 总结：你已经接近“零代码建模”

\| 模型定义        | ✅ YAML                     |
\| CRUD 路由注册   | ✅ 自动                     |
\| 字段和类型       | ✅ YAML → Column 构建        |
\| 视图模型支持    | ✅ `is_view: true`           |
\| 自定义保存逻辑  | ✅ `save_via_view()` 可选定义 |

---

## ✅ Bonus（可选增强）：

* 加缓存避免重复加载模型；
* 将 `model_registry` 变成全局 `get_model_by_name()` 工具；
* 支持复合主键、关系字段、外键；
* 自动建表（跳过视图）；

---

是否需要我继续扩展这一套机制：

* 加入动态外键字段？
* 生成 `save_via_view()` 的默认模板？
* 或者增加 YAML 中继承关系（逻辑视图）支持？

你现在已经站在一个高度灵活的全自动 CRUD 平台上了 💪。
