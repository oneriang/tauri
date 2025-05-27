#!/bin/bash
set -e

# 参数检查
if [ -z "$1" ]; then
  echo "Usage: $0 <project_name>"
  exit 1
fi

PROJECT_NAME=$1
PROJECT_DIR="$PWD/$PROJECT_NAME"

echo "创建 项目目录结构..."
mkdir -p $PROJECT_DIR/{app/{core,models,routers,static,static/locales,static/js,templates,templates/partials},scripts/templates}
cd $PROJECT_DIR

cat > requirements.txt << 'EOL'
fastapi>=0.68.0
sqlalchemy>=1.4.0
jinja2>=3.0.0
python-multipart>=0.0.5
uvicorn>=0.15.0
python-dotenv>=0.19.0
itsdangerous>=2.0.0
matplotlib>=3.0.0  # 新增图表库
EOL

echo "创建 虚拟环境..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

echo "生成核心基类..."
# base_model.py
cat > app/core/base_model.py << 'EOL'
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer

Base = declarative_base()

class BaseModel(Base):
    __abstract__ = True
    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    
    @classmethod
    def get_router(cls):
        from app.core.base_crud import BaseCRUD
        return BaseCRUD.create_router(cls)
EOL


echo "生成权限认证模块..."
cat > app/core/auth.py << 'EOL'
from fastapi import Request, HTTPException, Depends
from app.models import get_db
from app.models.m_users import MUsers
from sqlalchemy.orm import Session

def get_current_user(request: Request, db: Session = Depends(get_db)) -> MUsers:
    user_id = request.session.get("user_id")
    if not user_id:
        raise HTTPException(status_code=401, detail="ログインが必要です")
    user = db.query(MUsers).filter(MUsers.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="ユーザーが存在しません")
    return user
EOL

echo "生成核心CRUD逻辑（支持分页、搜索、权限）..."
# base_crud.py
cat > app/core/base_crud.py << 'EOL'
from fastapi import APIRouter, Depends, HTTPException, Request, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.orm import Session
from fastapi.templating import Jinja2Templates
from typing import Type
from sqlalchemy import or_
from app.models import get_db
from app.core.auth import get_current_user

templates = Jinja2Templates(directory="app/templates")

class BaseCRUD:
    @classmethod
    def create_router(cls, model: Type):
        router = APIRouter(prefix=f"/{model.__tablename__}", tags=[model.__tablename__])
        template_base = model.__tablename__
        
        @router.get("/", response_class=HTMLResponse)
        async def read_items(
            request: Request,
            db: Session = Depends(get_db),
            current_user=Depends(get_current_user),
            page: int = 1,
            per_page: int = 10,
            q: str = None
        ):
            query = db.query(model)
            if q:
                filters = [
                    col.ilike(f"%{q}%")
                    for col in model.__table__.columns
                    if hasattr(col.type, "python_type") and col.type.python_type == str
                ]
                if filters:
                    query = query.filter(or_(*filters))
            total = query.count()
            items = query.offset((page - 1) * per_page).limit(per_page).all()
            fields = [col for col in model.__table__.columns if col.name != 'id']
            return templates.TemplateResponse(
                f"{template_base}/list.html",
                {
                    "request": request,
                    "items": items,
                    "fields": fields,
                    "table_name": model.__tablename__,
                    "model_name": model.__name__,
                    "page": page,
                    "per_page": per_page,
                    "total": total,
                    "q": q or ""
                }
            )

        def column_to_dict(col):
            """将 SQLAlchemy Column 转换为包含元信息的字典"""
            col_type = str(col.type)
            html_type = "text"
            
            if "Integer" in col_type:
                html_type = "number"
            elif "Date" in col_type:
                html_type = "date"
            elif "DateTime" in col_type:
                html_type = "datetime-local"
            elif "Text" in col_type or col.type.python_type == str and col.type.length and col.type.length > 200:
                html_type = "textarea"

            return {
                "name": col.name,
                "type": col.type,
                "nullable": col.nullable,
                "required": not col.nullable,
                "label": col.name.replace("_", " ").title(),
                "html_type": html_type
            }

        @router.get("/new", response_class=HTMLResponse)
        async def create_form(request: Request):
            # fields = [column_to_dict(col) for col in model.__table__.columns if col.name != 'id']
            fields = getattr(model, '__fields__', [])
            return templates.TemplateResponse(
                f"{template_base}/form.html",
                {
                    "request": request, 
                    "item": None,
                    "fields": fields,
                    "table_name": model.__tablename__,
                    "model_name": model.__name__
                }
            )

        @router.get("/{item_id}/edit", response_class=HTMLResponse)
        async def edit_form(request: Request, item_id: int, db: Session = Depends(get_db)):
            item = db.query(model).filter(model.id == item_id).first()
            if not item:
                raise HTTPException(status_code=404, detail="Item not found")
            # fields = [column_to_dict(col) for col in model.__table__.columns if col.name != 'id']
            fields = getattr(model, '__fields__', [])
            return templates.TemplateResponse(
                f"{template_base}/form.html",
                {
                    "request": request,
                    "item": item,
                    "fields": fields,
                    "table_name": model.__tablename__,
                    "model_name": model.__name__
                }
            )
        
        @router.post("/", response_class=HTMLResponse)
        async def create_item(request: Request, db: Session = Depends(get_db)):
            try:
                form_data = await request.form()
                # 过滤掉空值和ID字段
                item_data = {k: v for k, v in form_data.items() if v and k != 'id'}
                item = model(**item_data)
                db.add(item)
                db.commit()
                db.refresh(item)
                return RedirectResponse(url=f"/{model.__tablename__}", status_code=303)
            except Exception as e:
                raise HTTPException(status_code=400, detail=str(e))
        
        @router.get("/{item_id}", response_class=HTMLResponse)
        async def read_item(request: Request, item_id: int, db: Session = Depends(get_db)):
            item = db.query(model).filter(model.id == item_id).first()
            if not item:
                raise HTTPException(status_code=404, detail="Item not found")
            
            fields = [col for col in model.__table__.columns if col.name != 'id']
            return templates.TemplateResponse(
                f"{template_base}/detail.html",
                {
                    "request": request,
                    "item": item,
                    "table_name": model.__tablename__,
                    "model_name": model.__name__,
                    "fields": fields
                }
            )
        
        @router.post("/{item_id}", response_class=HTMLResponse)
        async def update_item(request: Request, item_id: int, db: Session = Depends(get_db)):
            try:
                item = db.query(model).filter(model.id == item_id).first()
                if not item:
                    raise HTTPException(status_code=404, detail="Item not found")
                
                form_data = await request.form()
                for key, value in form_data.items():
                    if hasattr(item, key) and key != 'id':
                        setattr(item, key, value)
                
                db.commit()
                return RedirectResponse(url=f"/{model.__tablename__}", status_code=303)
            except Exception as e:
                raise HTTPException(status_code=400, detail=str(e))
        
        @router.delete("/{item_id}")
        async def delete_item(item_id: int, db: Session = Depends(get_db)):
            item = db.query(model).filter(model.id == item_id).first()
            if not item:
                raise HTTPException(status_code=404, detail="Item not found")
            
            db.delete(item)
            db.commit()
            return {"message": "Item deleted successfully"}

        return router
EOL

echo "生成模型和路由生成脚本..."
mkdir -p scripts/templates

# 生成脚本
cat > scripts/generate.py << 'EOL'
import os
from pathlib import Path
import pprint

# 表定义配置（日语字段说明）
TABLES = {
    "t_work": {
        "fields": [
            {"name": "customer_id", "type": "Integer", "required": True, "default": None, "label": "顧客ID"},
            {"name": "slip_number", "type": "String(50)", "required": True, "default": None, "label": "伝票番号"},
            {"name": "title", "type": "String(200)", "required": True, "default": None, "label": "タイトル"},
            {"name": "facilitator_id", "type": "String(50)", "required": True, "default": None, "label": "進行者ID"},
            {"name": "version_id", "type": "Integer", "required": True, "default": None, "label": "バージョンID"},
            {"name": "os_id", "type": "Integer", "required": True, "default": None, "label": "OS ID"},
            {"name": "folder_id", "type": "Integer", "required": True, "default": None, "label": "フォルダID"},
            {"name": "delflg", "type": "Integer", "required": False, "default": 0, "label": "削除フラグ"},
            {"name": "mountflg", "type": "Integer", "required": False, "default": 0, "label": "マウントフラグ"},
            {"name": "mountflgstr", "type": "String(10)", "required": False, "default": None, "label": "マウントフラグ文字列"}
        ]
    },
    "t_work_sub": {
        "name": "作業サブテーブル",
        "description": "作業の詳細情報を管理",
        "fields": [
            {"name": "work_id", "type": "Integer", "required": True, "default": None, "label": "作業ID"},
            {"name": "workclass_id", "type": "Integer", "required": True, "default": None, "label": "作業分類ID"},
            {"name": "urtime", "type": "DateTime", "required": False, "default": None, "label": "開始時間"},
            {"name": "mtime", "type": "DateTime", "required": False, "default": None, "label": "変更時間"},
            {"name": "durtime", "type": "DateTime", "required": False, "default": None, "label": "実行時間"},
            {"name": "comment", "type": "Text", "required": True, "default": None, "label": "コメント"},
            {"name": "working_user_id", "type": "Integer", "required": True, "default": None, "label": "作業者ID"},
            {"name": "delflg", "type": "Integer", "required": True, "default": None, "label": "削除フラグ"}
        ]
    },
    "m_customers": {
        "name": "顧客マスタ",
        "description": "顧客情報を管理",
        "fields": [
            {"name": "code", "type": "String(20)", "required": True, "default": None, "label": "顧客コード"},
            {"name": "name", "type": "String(100)", "required": True, "default": None, "label": "顧客名"},
            {
                "name": "delflg", 
                "type": "Integer", 
                "required": True, 
                "default": None, 
                "label": "削除フラグ",
                "widget_type": "select",
                "choices": [
                    {"value": 1, "label": "低"},
                    {"value": 2, "label": "中"},
                    {"value": 3, "label": "高"}
                ]
            }
        ]
    },
    "m_folder": {
        "name": "フォルダマスタ",
        "description": "フォルダ情報を管理",
        "fields": [
            {"name": "name", "type": "String(100)", "required": True, "default": None, "label": "フォルダ名"},
            {"name": "ip", "type": "String(50)", "required": True, "default": None, "label": "IPアドレス"},
            {"name": "path", "type": "String(200)", "required": True, "default": None, "label": "パス"},
            {"name": "admin", "type": "Integer", "required": True, "default": None, "label": "管理者"},
            {"name": "user_name", "type": "String(50)", "required": True, "default": None, "label": "ユーザー名"},
            {"name": "passwd", "type": "String(100)", "required": True, "default": None, "label": "パスワード"},
            {"name": "delflg", "type": "Integer", "required": False, "default": 0, "label": "削除フラグ"}
        ]
    },
    "m_os": {
        "name": "OSマスタ",
        "description": "OS情報を管理",
        "fields": [
            {"name": "name", "type": "String(50)", "required": True, "default": None, "label": "OS名"},
            {"name": "comment", "type": "String(200)", "required": True, "default": None, "label": "コメント"},
            {
                "name": "delflg", 
                "type": "Integer", 
                "required": False, 
                "default": 0, 
                "label": "削除フラグ",
                "widget_type": "radio",
                "choices": [
                    {"value": 0, "label": "未完了"},
                    {"value": 1, "label": "進行中"},
                    {"value": 2, "label": "完了"}
                ]
            }
        ]
    },
    "m_users": {
        "name": "ユーザーマスタ",
        "description": "ユーザー情報を管理",
        "fields": [
            {"name": "userid", "type": "String(50)", "required": True, "default": None, "label": "ユーザーID"},
            {"name": "passwd", "type": "String(100)", "required": True, "default": None, "label": "パスワード"},
            {"name": "fname", "type": "String(50)", "required": True, "default": None, "label": "名前"},
            {"name": "lname", "type": "String(50)", "required": True, "default": None, "label": "姓"},
            {"name": "permission", "type": "Integer", "required": True, "default": None, "label": "権限"},
            {"name": "facilitator", "type": "Integer", "required": True, "default": None, "label": "進行者"},
            {"name": "delflg", "type": "Integer", "required": True, "default": None, "label": "削除フラグ"}
        ]
    },
    "m_version": {
        "name": "バージョンマスタ",
        "description": "バージョン情報を管理",
        "fields": [
            {"name": "name", "type": "String(50)", "required": True, "default": None, "label": "バージョン名"},
            {"name": "comment", "type": "String(200)", "required": True, "default": None, "label": "コメント"},
            {"name": "delflg", "type": "Integer", "required": False, "default": 0, "label": "削除フラグ"},
            {"name": "sort", "type": "Integer", "required": True, "default": None, "label": "ソート順"}
        ]
    },
    "m_workclass": {
        "name": "作業分類マスタ",
        "description": "作業分類情報を管理",
        "fields": [
            {"name": "name", "type": "String(50)", "required": True, "default": None, "label": "分類名"},
            {"name": "comment", "type": "String(200)", "required": True, "default": None, "label": "コメント"}
        ]
    },
    "t_logs": {
        "name": "ログテーブル",
        "description": "システムログを管理",
        "fields": [
            {"name": "user_id", "type": "Integer", "required": False, "default": None, "label": "ユーザーID"},
            {"name": "user_name", "type": "String(50)", "required": False, "default": None, "label": "ユーザー名"},
            {"name": "folder_name", "type": "String(100)", "required": False, "default": None, "label": "フォルダ名"},
            {"name": "work_content", "type": "Text", "required": False, "default": None, "label": "作業内容"},
            {"name": "result", "type": "Text", "required": False, "default": None, "label": "結果"},
            {"name": "created", "type": "DateTime", "required": False, "default": "func.now()", "label": "作成日時"}
        ]
    }
}

#  模板定义
TEMPLATES = {
    "model.py.j2": """
from sqlalchemy import Column, {field_types}
from app.core.base_model import BaseModel

class {model_name}(BaseModel):
    __tablename__ = "{table_name}"
    
{columns}

    __fields__ = {fields}
""",

    "router.py.j2": """
from fastapi import APIRouter
from app.models.{table_name} import {model_name}

# 创建 路由实例
{table_name}_model = {model_name}
router = {table_name}_model.get_router()
""",

    "list.html.j2": """
{{% extends "base_list.html" %}}
{{% set new_url = '/' ~ table_name ~ '/new' %}}
{{% block header_title %}}{{{{ model_name }}}} 管理{{% endblock %}}
""",

    "form.html.j2": """
{{% extends "form.html" %}}
""",

    "detail.html.j2": """
{{% extends "detail.html" %}}
"""
}

def get_field_type(field):
    """根据字段类型返回对应的HTML输入类型"""
    if field.get('widget_type'):
        return field['widget_type']

    field_type = field['type']
    
    if 'Integer' in field_type:
        return 'number'
    elif 'Date' in field_type:
        return 'date'
    elif 'DateTime' in field_type:
        return 'datetime-local'
    elif 'Boolean' in field_type:
        return 'checkbox'
    elif 'Text' in field_type or len(str(field.get("label", ""))) > 100:
        return 'textarea'
    else:
        return 'text'


def get_unique_types(fields):
    """获取字段中使用的唯一SQL类型"""
    types = set()
    for field in fields:
        field_type = field['type']
        if field_type.startswith('String'):
            types.add('String')
        else:
            types.add(field_type)
    return sorted(types)

def generate():
    for table_name, config in TABLES.items():
        model_name = ''.join([word.capitalize() for word in table_name.split('_')])
        
        # 生成字段定义
        columns = []
        for field in config["fields"]:
            column_def = f"    {field['name']} = Column({field['type']}"
            if not field['required']:
                column_def += ", nullable=True"
            if field.get('default') is not None:
                if isinstance(field['default'], str):
                    column_def += f", default='{field['default']}'"
                else:
                    column_def += f", default={field['default']}"
            column_def += ")"
            columns.append(column_def)
        
            # 添加 html_type 属性
            field['html_type'] = get_field_type(field)
            
            # 确保 widget_type 和 choices 也被传入模板
            if 'widget_type' in field:
                field['widget_type'] = field['widget_type']
            if 'choices' in field:
                field['choices'] = field['choices']
                
        context = {
            "table_name": table_name,
            "model_name": model_name,
            "fields": pprint.pformat(config["fields"], indent=4, width=100),
            "field_types": ", ".join(get_unique_types(config["fields"])),
            "columns": "\n".join(columns)
        }

        print(config["fields"])

        # 生成所有 模板文件
        for template_name, output_path in [
            ("model.py.j2", f"app/models/{table_name}.py"),
            ("router.py.j2", f"app/routers/{table_name}.py"),
            ("list.html.j2", f"app/templates/{table_name}/list.html"),
            ("form.html.j2", f"app/templates/{table_name}/form.html"),
            ("detail.html.j2", f"app/templates/{table_name}/detail.html")
        ]:
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            with open(output_path, "w", encoding='utf-8') as f:
                content = TEMPLATES[template_name].format(**context)
                f.write(content)
                
        print(f"Generated files for {table_name}")

    # 生成__init__.py文件
    with open("app/models/__init__.py", "a", encoding='utf-8') as f:
        f.write("\n# Import all models\n")
        for table_name in TABLES.keys():
            model_name = ''.join([word.capitalize() for word in table_name.split('_')])
            f.write(f"from .{table_name} import {model_name}\n")
    
    with open("app/routers/__init__.py", "w", encoding='utf-8') as f:
        f.write("# Routers module\n")

if __name__ == "__main__":
    generate()
    print("代码生成完成！")
EOL


# 创建 基础 模板
cat > app/templates/base.html << 'EOL'
<!DOCTYPE html>
<html lang="ja">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        {% block title %}
            <title>FastAPI CRUD アプリ</title>
        {% endblock %}

        <!-- Tailwind CSS -->
        <script src="https://cdn.tailwindcss.com "></script>

        <!-- Font Awesome -->
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">

        <!-- HTMX -->
        <script src="https://unpkg.com/htmx.org@1.9.6"></script>

        <!-- 自定义样式 -->
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
            body { font-family: 'Inter', sans-serif; }

            .glass-effect {
                background: rgba(255, 255, 255, 0.95);
                backdrop-filter: blur(20px);
                border: 1px solid rgba(255, 255, 255, 0.2);
            }
            .gradient-bg {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            }
            .fade-in {
                animation: fadeIn 0.8s ease-out forwards;
            }
            @keyframes fadeIn {
                from { opacity: 0; transform: translateY(20px); }
                to { opacity: 1; transform: translateY(0); }
            }
            .slide-in {
                animation: slideIn 0.6s ease-out forwards;
            }
            @keyframes slideIn {
                from { transform: translateX(-20px); opacity: 0; }
                to { transform: translateX(0); opacity: 1; }
            }
            .card-hover:hover {
                transform: translateY(-2px);
                box-shadow: 0 10px 25px -3px rgba(0, 0, 0, 0.1);
            }
        </style>

        <style>
            @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
            body { font-family: 'Inter', sans-serif; }
            .glass-effect {
                background: rgba(255, 255, 255, 0.95);
                backdrop-filter: blur(20px);
                border: 1px solid rgba(255, 255, 255, 0.2);
            }
            .gradient-bg {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
            }
            .card-hover {
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            }
            .card-hover:hover {
                transform: translateY(-2px);
                box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.1);
            }
            .btn-modern {
                transition: all 0.2s ease-in-out;
                position: relative;
                overflow: hidden;
            }
            .btn-modern:before {
                content: '';
                position: absolute;
                top: 0;
                left: -100%;
                width: 100%;
                height: 100%;
                background: linear-gradient(90deg, transparent, rgba(255,255,255,0.3), transparent);
                transition: left 0.5s;
            }
            .btn-modern:hover:before {
                left: 100%;
            }
            .fade-in {
                animation: fadeIn 0.8s ease-out forwards;
            }
            @keyframes fadeIn {
                from { opacity: 0; transform: translateY(20px); }
                to { opacity: 1; transform: translateY(0); }
            }
            .slide-in {
                animation: slideIn 0.6s ease-out forwards;
            }
            @keyframes slideIn {
                from { transform: translateX(-20px); opacity: 0; }
                to { transform: translateX(0); opacity: 1; }
            }
            .mobile-card {
                transition: all 0.2s ease;
            }
            .mobile-card:active {
                transform: scale(0.98);
            }
            /* Mobile specific styles */
            @media (max-width: 768px) {
                .mobile-hidden { display: none !important; }
                .mobile-full { width: 100% !important; }
                .mobile-stack { flex-direction: column !important; }
                .mobile-text-sm { font-size: 0.875rem !important; }
                .mobile-p-2 { padding: 0.5rem !important; }
                .mobile-mb-4 { margin-bottom: 1rem !important; }
            }
            
            /* Responsive table */
            .responsive-table {
                display: block;
                overflow-x: auto;
                white-space: nowrap;
            }
            
            @media (max-width: 640px) {
                .responsive-table {
                    display: none;
                }
                .mobile-card-view {
                    display: block;
                }
            }
            
            @media (min-width: 641px) {
                .mobile-card-view {
                    display: none;
                }
            }
            
            /* Mobile menu */
            .mobile-menu {
                transform: translateX(100%);
                transition: transform 0.3s ease-in-out;
            }
            .mobile-menu.open {
                transform: translateX(0);
            }
        </style>

        {% block head_extra %}
        {% endblock %}
    </head>
    <body class="gradient-bg">
        <!-- 导航栏 -->
        <nav class="glass-effect border-b border-white/20 sticky top-0 z-50">
            <div class="container mx-auto px-4 py-3 flex justify-between items-center">
                <h1 class="text-xl font-bold text-gray-800">
                    <i class="fas fa-chart-line text-purple-600 mr-2"></i>ダッシュボード
                </h1>
                <div class="flex items-center space-x-4">
                    <a href="/" class="text-gray-700 hover:text-purple-600">
                        <i class="fas fa-home"></i>
                    </a>
                    <a href="/logout" class="text-gray-700 hover:text-purple-600">
                        <i class="fas fa-sign-out-alt"></i>
                    </a>
                </div>
                <!-- Language Switcher -->
                <div class="flex items-center space-x-2">
                    <button onclick="I18N.setLanguage('ja')" class="text-gray-700 hover:text-purple-600">日本語</button>
                    <span class="text-gray-400">|</span>
                    <button onclick="I18N.setLanguage('en')" class="text-gray-700 hover:text-purple-600">English</button>
                </div>
            </div>
        </nav>

        <!-- 页面主体内容 -->
        <div class="container mx-auto px-4 py-6">
            {% block content %}
            {% endblock %}
        </div>

        <!-- 脚本 -->
        {% block scripts %}
        {% endblock %}
    </body>
</html>
EOL

# 创建 form 模板
cat > app/templates/form.html << 'EOL'
{% extends "base.html" %}
{% block title %}
    <title>{% if item %}編集{% else %}作成{% endif %} {{ model_name }}</title>
{% endblock %}

{% block content %}
<div class="max-w-3xl w-full mx-auto glass-effect rounded-2xl p-6 sm:p-8 shadow-xl fade-in">
    <h1 class="text-2xl sm:text-3xl font-bold mb-6 text-gray-800 text-center">
        {% if item %}編集{% else %}新規作成{% endif %} - {{ model_name }}
    </h1>
    <form method="post" 
        action="{% if item %}/{{ table_name }}/{{ item.id }}{% else %}/{{ table_name }}{% endif %}" 
        class="space-y-6">

        {% for field in fields %}
        {# 动态加载控件模板 #}
        {% set widget_template = {
            'radio': 'partials/_field_radio.html',
            'checkbox': 'partials/_field_checkbox.html',
            'select': 'partials/_field_select.html',
            'daterange': 'partials/_field_daterange.html'
        }.get(field.widget_type, 'partials/_field_default.html') %}

        {% include widget_template with context %}
        {% endfor %}

        {% for field in fields %}
        <div>
            <label class="block text-gray-700 font-semibold mb-2">
                {{ field.name.replace('_', ' ').title() }}
            </label>
            {% set field_value = item[field.name] if item and item[field.name] is not none else '' %}
            <input 
                type="{% if 'Integer' in field.type.__class__.__name__ %}number{% else %}text{% endif %}"
                name="{{ field.name }}" 
                value="{{ field_value }}"
                class="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm sm:text-base focus:outline-none focus:ring-2 focus:ring-purple-500"
                {% if not field.nullable %}required{% endif %}>
        </div>
        {% endfor %}
        
        {% for field in fields %}
        <div>
            <label class="block text-gray-700 font-semibold mb-2">
                {{ field.name.replace('_', ' ').title() }}
            </label>
            {% set field_value = item[field.name] if item and item[field.name] is not none else '' %}
            
            {% if field.html_type == 'textarea' %}
            <textarea 
                name="{{ field.name }}{% if not field.nullable %}" required{% endif %} 
                class="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm sm:text-base focus:outline-none focus:ring-2 focus:ring-purple-500"
            >{{ field_value }}</textarea>
            
            {% elif field.html_type == 'checkbox' %}
            <input 
                type="checkbox" 
                name="{{ field.name }}{% if not field.nullable %}" required{% endif %} 
                value="1" 
                {% if field_value %}checked{% endif %} 
                class="rounded text-purple-600 focus:ring-purple-500">
            
            {% elif field.html_type == 'date' or field.html_type == 'datetime-local' %}
            <input 
                type="{{ field.html_type }}{% if not field.nullable %}" required{% endif %} 
                name="{{ field.name }}{% if not field.nullable %}" required{% endif %} 
                value="{% if field_value %}{ field_value.isoformat().split('.')[0].replace(' ', 'T') }{% endif %}"
                class="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm sm:text-base focus:outline-none focus:ring-2 focus:ring-purple-500">
            
            {% else %}
            <input 
                type="text" 
                name="{{ field.name }}{% if not field.nullable %}" required{% endif %} 
                value="{{ field_value }}"
                class="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm sm:text-base focus:outline-none focus:ring-2 focus:ring-purple-500">
            {% endif %}
        </div>
        {% endfor %}

        <div class="flex flex-col sm:flex-row justify-between gap-4 pt-6">
            <a href="/{{ table_name }}" 
            class="bg-gray-200 text-gray-800 px-6 py-3 rounded-xl hover:bg-gray-300 text-center">
                <i class="fas fa-arrow-left mr-2"></i>戻る
            </a>
            <button type="submit" 
                    class="bg-purple-600 text-white px-6 py-3 rounded-xl hover:bg-purple-700 text-center">
                <i class="fas fa-save mr-2"></i>保存
            </button>
        </div>
    </form>
</div>
{% endblock %}
EOL

# 创建 detail 模板
cat > app/templates/detail.html << 'EOL'
{% extends "base.html" %}
{% block title %}
    <title>{{ model_name }} 詳細</title>
{% endblock %}

{% block content %}
<div class="max-w-4xl w-full mx-auto glass-effect rounded-2xl p-6 sm:p-8 shadow-xl fade-in">
    <h1 class="text-2xl sm:text-3xl font-bold mb-6 text-gray-800 text-center sm:text-left">
        <i class="fas fa-info-circle text-purple-600 mr-2"></i>{{ model_name }} 詳細
    </h1>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
            <h2 class="text-gray-600 font-semibold">ID</h2>
            <p class="text-base sm:text-lg text-gray-800">{{ item.id }}</p>
        </div>
        {% for field in fields %}
        <div>
            <h2 class="text-gray-600 font-semibold">{{ field.name.replace('_', ' ').title() }}</h2>
            <p class="text-base sm:text-lg text-gray-800">{{ item[field.name] if item[field.name] is not none else '—' }}</p>
        </div>
        {% endfor %}
    </div>
    <div class="flex flex-col sm:flex-row justify-end mt-8 space-y-4 sm:space-y-0 sm:space-x-4">
        <a href="/{{ table_name }}/{{ item.id }}/edit" 
           class="bg-yellow-500 text-white px-6 py-3 rounded-xl hover:bg-yellow-600 text-center">
            <i class="fas fa-edit mr-2"></i>編集
        </a>
        <a href="/{{ table_name }}" 
           class="bg-gray-200 text-gray-800 px-6 py-3 rounded-xl hover:bg-gray-300 text-center">
            <i class="fas fa-list mr-2"></i>一覧へ戻る
        </a>
    </div>
</div>
{% endblock %}
EOL


# 创建 _field_default 模板
cat > app/templates/partials/_field_default.html << 'EOL'
<div class="mb-4">
    <label class="block text-gray-700 font-semibold mb-2">{{ field.label }}</label>
    <input 
        type="{{ field.html_type }}"
        name="{{ field.name }}" 
        value="{{ item[field.name] if item and item[field.name] is not none else '' }}"
        class="w-full border border-gray-300 rounded-xl px-4 py-3 focus:outline-none focus:ring-2 focus:ring-purple-500"
        {{ "required" if not field.nullable }}
    >
</div>
EOL

# 创建 _field_radio 模板
cat > app/templates/partials/_field_radio.html << 'EOL'
<div class="mb-4">
    <label class="block text-gray-700 font-semibold mb-2">{{ field.label }}</label>
    {% for option in field.choices %}
    <div class="flex items-center space-x-2 mt-1">
        <input 
            type="radio" 
            id="{{ field.name }}_{{ option.value }}" 
            name="{{ field.name }}" 
            value="{{ option.value }}" 
            {% if item and item[field.name] == option.value %}checked{% endif %}
            class="w-4 h-4 text-purple-600 focus:ring-purple-500"
        >
        <label for="{{ field.name }}_{{ option.value }}" class="text-sm text-gray-700">
            {{ option.label }}
        </label>
    </div>
    {% endfor %}
</div>
EOL

# 创建 _field_checkbox 模板
cat > app/templates/partials/_field_checkbox.html << 'EOL'
<div class="mb-4 flex items-center space-x-2">
    <input 
        type="checkbox" 
        id="{{ field.name }}" 
        name="{{ field.name }}" 
        value="1" 
        {% if item and item[field.name] %}checked{% endif %}
        class="w-4 h-4 text-purple-600 focus:ring-purple-500"
    >
    <label for="{{ field.name }}" class="text-sm text-gray-700">{{ field.label }}</label>
</div>
EOL

# 创建 _field_select 模板
cat > app/templates/partials/_field_select.html << 'EOL'
<div class="mb-4">
    <label class="block text-gray-700 font-semibold mb-2">{{ field.label }}</label>
    <select 
        name="{{ field.name }}" 
        class="w-full border border-gray-300 rounded-xl px-4 py-3 focus:outline-none focus:ring-2 focus:ring-purple-500"
        {{ "required" if not field.nullable }}
    >
        {% for option in field.choices %}
        <option value="{{ option.value }}" {% if item and item[field.name] == option.value %}selected{% endif %}>
            {{ option.label }}
        </option>
        {% endfor %}
    </select>
</div>
EOL

# 创建 _field_daterange 模板
cat > app/templates/partials/_field_daterange.html << 'EOL'
<div class="mb-4">
    <label class="block text-gray-700 font-semibold mb-2">{{ field.label }}</label>
    <div class="grid grid-cols-2 gap-4">
        <div>
            <label class="block text-xs text-gray-600 mb-1">開始日</label>
            <input 
                type="date" 
                name="{{ field.name }}_start"
                value="{{ item.start_date }}" 
                class="w-full border border-gray-300 rounded-xl px-4 py-3"
            >
        </div>
        <div>
            <label class="block text-xs text-gray-600 mb-1">終了日</label>
            <input 
                type="date" 
                name="{{ field.name }}_end"
                value="{{ item.end_date }}" 
                class="w-full border border-gray-300 rounded-xl px-4 py-3"
            >
        </div>
    </div>
</div>
EOL

# 创建 _pagination 模板
cat > app/templates/partials/_pagination.html << 'EOL'
<div class="mt-6 flex justify-center items-center space-x-2 text-sm">
    {% if page > 1 %}
    <a href="?page={{ page - 1 }}&q={{ q }}" 
       class="px-3 py-2 rounded bg-gray-200 text-gray-700 hover:bg-gray-300">
        ← 前へ
    </a>
    {% endif %}
    <span class="px-4 py-2 text-gray-800 font-semibold bg-white border border-gray-300 rounded">
        {{ page }}
    </span>
    {% if total > page * per_page %}
    <a href="?page={{ page + 1 }}&q={{ q }}" 
       class="px-3 py-2 rounded bg-gray-200 text-gray-700 hover:bg-gray-300">
        次へ →
    </a>
    {% endif %}
</div>
EOL

# 创建 _search 模板
cat > app/templates/partials/_search.html << 'EOL'
<form method="get" class="mb-4 flex items-center gap-2">
    <input type="text" name="q" value="{{ q }}" placeholder="検索キーワード"
           class="border border-gray-300 rounded px-4 py-2 w-full max-w-xs">
    <button type="submit"
            class="bg-purple-600 text-white px-4 py-2 rounded hover:bg-purple-700">
        検索
    </button>
</form>
EOL

# 创建 _table 模板
cat > app/templates/partials/_table.html << 'EOL'
<div class="slide-in glass-effect rounded-2xl shadow-xl overflow-hidden responsive-table">
    <div class="bg-gradient-to-r from-gray-50 to-gray-100 px-4 lg:px-8 py-4 lg:py-6 border-b">
        <h2 class="text-xl lg:text-2xl font-bold text-gray-800">
            <i class="fas fa-table mr-2"></i>データ一覧
        </h2>
    </div>
    <div class="overflow-x-auto">
        <table class="min-w-full">
            <thead class="bg-gradient-to-r from-gray-100 to-gray-200">
                <tr>
                    <th class="px-3 lg:px-6 py-3 lg:py-4 text-left text-xs lg:text-sm font-semibold text-gray-700 uppercase tracking-wider">
                        <i class="fas fa-key mr-1 lg:mr-2"></i>ID
                    </th>
                    {% for field in fields %}
                    <th class="px-3 lg:px-6 py-3 lg:py-4 text-left text-xs lg:text-sm font-semibold text-gray-700 uppercase tracking-wider">
                        <i class="fas fa-info-circle mr-1 lg:mr-2"></i>
                        <span class="hidden sm:inline">{{ field.name.replace('_', ' ').title() }}</span>
                        <span class="sm:hidden">{{ field.name[:8] + '...' if field.name|length > 8 else field.name }}</span>
                    </th>
                    {% endfor %}
                    <th class="px-3 lg:px-6 py-3 lg:py-4 text-left text-xs lg:text-sm font-semibold text-gray-700 uppercase tracking-wider">
                        <i class="fas fa-cogs mr-1 lg:mr-2"></i>操作
                    </th>
                </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
                {% for item in items %}
                <tr class="mobile-card hover:bg-gray-50">
                    <td class="px-3 lg:px-6 py-3 lg:py-4 whitespace-nowrap text-xs lg:text-sm font-medium text-gray-900">
                        <span class="bg-blue-100 text-blue-800 px-2 lg:px-3 py-1 rounded-full text-xs font-semibold">
                            {{ item.id }}
                        </span>
                    </td>
                    {% for field in fields %}
                    <td class="px-3 lg:px-6 py-3 lg:py-4 whitespace-nowrap text-xs lg:text-sm text-gray-700">
                        <span class="truncate block" style="max-width: 120px;">
                            {{ item[field.name] if item[field.name] is not none else '—' }}
                        </span>
                    </td>
                    {% endfor %}
                    <td class="px-3 lg:px-6 py-3 lg:py-4 whitespace-nowrap text-xs lg:text-sm font-medium">
                        <div class="flex flex-col lg:flex-row space-y-1 lg:space-y-0 lg:space-x-2">
                            <a href="/{{ table_name }}/{{ item.id }}" 
                               class="btn-modern bg-blue-500 hover:bg-blue-600 text-white px-2 lg:px-4 py-1 lg:py-2 rounded-lg transition-all inline-flex items-center justify-center text-xs">
                                <i class="fas fa-eye mr-1"></i><span class="hidden lg:inline">詳細</span>
                            </a>
                            <a href="/{{ table_name }}/{{ item.id }}/edit" 
                               class="btn-modern bg-yellow-500 hover:bg-yellow-600 text-white px-2 lg:px-4 py-1 lg:py-2 rounded-lg transition-all inline-flex items-center justify-center text-xs">
                                <i class="fas fa-edit mr-1"></i><span class="hidden lg:inline">編集</span>
                            </a>
                            <button hx-delete="/{{ table_name }}/{{ item.id }}" 
                                    hx-confirm="本当に削除しますか？"
                                    hx-target="closest tr"
                                    hx-swap="outerHTML swap:1s"
                                    class="btn-modern bg-red-500 hover:bg-red-600 text-white px-2 lg:px-4 py-1 lg:py-2 rounded-lg transition-all inline-flex items-center justify-center text-xs">
                                <i class="fas fa-trash mr-1"></i><span class="hidden lg:inline">削除</span>
                            </button>
                        </div>
                    </td>
                </tr>
                {% endfor %}
                {% if not items %}
                <tr>
                    <td colspan="{{ fields|length + 2 }}" class="px-6 py-12 text-center">
                        <div class="text-gray-500">
                            <i class="fas fa-inbox text-4xl mb-4"></i>
                            <p class="text-lg font-medium">データがありません</p>
                            <p class="text-sm">新規作成ボタンからデータを追加してください</p>
                        </div>
                    </td>
                </tr>
                {% endif %}
            </tbody>
        </table>
    </div>
</div>
EOL

# 创建 基础 模板 base_list.html
cat > app/templates/base_list.html << 'EOL'
{% extends "base.html" %}
{% block content %}
<div class="container mx-auto px-4 py-4 lg:px-6 lg:py-8">
    <!-- Desktop Header Section -->
    <div class="hidden lg:block fade-in mb-8">
        <div class="glass-effect rounded-2xl p-8 shadow-xl">
            <div class="flex items-center justify-between">
                <div>
                    <h1 class="text-4xl font-bold text-gray-800 mb-2">
                        <i class="fas fa-database text-purple-600 mr-3"></i>
                        {% block header_title %}データ管理{% endblock %}
                    </h1>
                    <p class="text-lg text-gray-600">データの閲覧・編集・管理</p>
                </div>
                <div class="flex space-x-4">
                    <a href="{{ new_url }}" 
                       class="btn-modern bg-gradient-to-r from-green-500 to-blue-600 text-white px-8 py-3 rounded-xl font-semibold hover:from-green-600 hover:to-blue-700 transform hover:scale-105 shadow-lg">
                        <i class="fas fa-plus mr-2"></i>新規作成
                    </a>
                    <button onclick="location.reload()" 
                            class="btn-modern bg-gradient-to-r from-gray-500 to-gray-600 text-white px-6 py-3 rounded-xl font-semibold hover:from-gray-600 hover:to-gray-700 transform hover:scale-105 shadow-lg">
                        <i class="fas fa-sync-alt mr-2"></i>更新
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- Stats Cards -->
    <div class="slide-in grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 lg:gap-6 mb-6 lg:mb-8">
        {% block stats_cards %}
        <div class="glass-effect rounded-xl p-4 lg:p-6 card-hover">
            <div class="flex items-center">
                <div class="bg-blue-500 rounded-full p-2 lg:p-3 mr-3 lg:mr-4">
                    <i class="fas fa-list text-white text-lg lg:text-xl"></i>
                </div>
                <div>
                    <p class="text-gray-600 text-xs lg:text-sm">総件数</p>
                    <p class="text-xl lg:text-2xl font-bold text-gray-800">{{ items|length }}</p>
                </div>
            </div>
        </div>
        <div class="glass-effect rounded-xl p-4 lg:p-6 card-hover">
            <div class="flex items-center">
                <div class="bg-green-500 rounded-full p-2 lg:p-3 mr-3 lg:mr-4">
                    <i class="fas fa-table text-white text-lg lg:text-xl"></i>
                </div>
                <div>
                    <p class="text-gray-600 text-xs lg:text-sm">テーブル名</p>
                    <p class="text-sm lg:text-lg font-semibold text-gray-800">{{ table_name }}</p>
                </div>
            </div>
        </div>
        <div class="glass-effect rounded-xl p-4 lg:p-6 card-hover sm:col-span-2 lg:col-span-1">
            <div class="flex items-center">
                <div class="bg-purple-500 rounded-full p-2 lg:p-3 mr-3 lg:mr-4">
                    <i class="fas fa-columns text-white text-lg lg:text-xl"></i>
                </div>
                <div>
                    <p class="text-gray-600 text-xs lg:text-sm">項目数</p>
                    <p class="text-xl lg:text-2xl font-bold text-gray-800">{{ fields|length + 1 }}</p>
                </div>
            </div>
        </div>
        {% endblock %}
    </div>

    <!-- Search Form -->
    {% include "partials/_search.html" with context %}

    <!-- Table View -->
    {% include "partials/_table.html" with context %}

    <!-- Pagination -->
    {% include "partials/_pagination.html" with context %}

    <!-- Mobile Card View -->
    {% block mobile_card_view %}
    <div class="mobile-card-view space-y-4">
        <div class="glass-effect rounded-xl p-4 shadow-lg">
            <h2 class="text-lg font-bold text-gray-800 mb-4">
                <i class="fas fa-list mr-2"></i>データ一覧
            </h2>
        </div>
        {% for item in items %}
        <div class="glass-effect rounded-xl p-4 shadow-lg mobile-card">
            <div class="flex justify-between items-start mb-3">
                <div class="flex items-center">
                    <span class="bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-xs font-semibold mr-3">
                        ID: {{ item.id }}
                    </span>
                </div>
                <div class="flex space-x-2">
                    <a href="/{{ table_name }}/{{ item.id }}" 
                       class="bg-blue-500 text-white p-2 rounded-lg">
                        <i class="fas fa-eye text-xs"></i>
                    </a>
                    <a href="/{{ table_name }}/{{ item.id }}/edit" 
                       class="bg-yellow-500 text-white p-2 rounded-lg">
                        <i class="fas fa-edit text-xs"></i>
                    </a>
                    <button hx-delete="/{{ table_name }}/{{ item.id }}" 
                            hx-confirm="本当に削除しますか？"
                            hx-target="closest .mobile-card"
                            hx-swap="outerHTML swap:1s"
                            class="bg-red-500 text-white p-2 rounded-lg">
                        <i class="fas fa-trash text-xs"></i>
                    </button>
                </div>
            </div>
            <div class="grid grid-cols-1 gap-2">
                {% for field in fields %}
                <div class="flex justify-between items-center py-1 border-b border-gray-100 last:border-b-0">
                    <span class="text-sm font-medium text-gray-600">{{ field.name.replace('_', ' ').title() }}:</span>
                    <span class="text-sm text-gray-800 truncate ml-2" style="max-width: 150px;">
                        {{ item[field.name] if item[field.name] is not none else '—' }}
                    </span>
                </div>
                {% endfor %}
            </div>
        </div>
        {% endfor %}
        {% if not items %}
        <div class="glass-effect rounded-xl p-8 text-center">
            <div class="text-gray-500">
                <i class="fas fa-inbox text-3xl mb-4"></i>
                <p class="text-lg font-medium">データがありません</p>
                <p class="text-sm">新規作成ボタンからデータを追加してください</p>
            </div>
        </div>
        {% endif %}
    </div>
    {% endblock %}

    <!-- Floating Action Button (Mobile) -->
    {% block mobile_fab %}
    <div class="lg:hidden fixed bottom-6 right-6 z-30">
        <a href="{{ new_url }}" 
           class="bg-gradient-to-r from-green-500 to-blue-600 text-white w-14 h-14 rounded-full shadow-lg flex items-center justify-center text-xl">
            <i class="fas fa-plus"></i>
        </a>
    </div>
    {% endblock %}
</div>
{% endblock %}

{% block scripts %}
<script>
    // Mobile menu functionality
    const mobileMenuBtn = document.getElementById('mobile-menu-btn');
    const mobileMenu = document.getElementById('mobile-menu');
    const mobileMenuOverlay = document.getElementById('mobile-menu-overlay');
    const closeMenuBtn = document.getElementById('close-menu');

    function openMobileMenu() {
        mobileMenu.classList.add('open');
        mobileMenuOverlay.classList.remove('opacity-0', 'invisible');
        document.body.style.overflow = 'hidden';
    }

    function closeMobileMenu() {
        mobileMenu.classList.remove('open');
        mobileMenuOverlay.classList.add('opacity-0', 'invisible');
        document.body.style.overflow = '';
    }

    mobileMenuBtn?.addEventListener('click', openMobileMenu);
    closeMenuBtn?.addEventListener('click', closeMobileMenu);
    mobileMenuOverlay?.addEventListener('click', closeMobileMenu);

    // HTMX event handlers
    document.addEventListener('htmx:beforeRequest', function(evt) {
        evt.target.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>処理中...';
        evt.target.disabled = true;
    });

    document.addEventListener('htmx:beforeSwap', function(evt) {
        if (evt.detail.target.tagName === 'TR' || evt.detail.target.classList.contains('mobile-card')) {
            evt.detail.target.style.opacity = '0';
            evt.detail.target.style.transform = 'translateX(-100%)';
        }
    });

    // Touch gesture support for mobile cards
    if (window.innerWidth <= 768) {
        let startY = 0;
        let startX = 0;
        document.addEventListener('touchstart', function(e) {
            startY = e.touches[0].clientY;
            startX = e.touches[0].clientX;
        });
        document.addEventListener('touchend', function(e) {
            let endY = e.changedTouches[0].clientY;
            let endX = e.changedTouches[0].clientX;
            let diffY = startY - endY;
            let diffX = startX - endX;
            if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 50) {
                if (diffX > 0 && startX > window.innerWidth * 0.8) {
                    openMobileMenu();
                } else if (diffX < 0 && mobileMenu.classList.contains('open')) {
                    closeMobileMenu();
                }
            }
        });
    }
</script>
{% endblock %}
EOL

# 生成登录页面 模板
cat > app/templates/login.html << 'EOL'

{% extends "base.html" %}
{% block title %}
    <title>ログイン</title>
{% endblock %}

{% block content %}
<div class="max-w-md w-full mx-auto glass-effect rounded-2xl p-8 shadow-lg space-y-6 fade-in">
    <h1 class="text-2xl font-bold text-center text-gray-800">
        <i class="fas fa-lock mr-2 text-purple-600"></i><span data-i18n="title">ログイン</span>
    </h1>
    <form method="post" action="/login" class="space-y-4">
        <div>
            <label class="block text-gray-700 font-medium mb-1" data-i18n="username">ユーザーID</label>
            <input type="text" name="userid" required
                   class="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500">
        </div>
        <div>
            <label class="block text-gray-700 font-medium mb-1" data-i18n="password">パスワード</label>
            <input type="password" name="passwd" required
                   class="w-full border border-gray-300 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500">
        </div>
        <button type="submit"
                class="w-full bg-purple-600 hover:bg-purple-700 text-white font-semibold py-3 rounded-xl shadow">
            <i class="fas fa-sign-in-alt mr-2"></i><span data-i18n="login">ログイン</span>
        </button>
    </form>
</div>
{% endblock %}

{% block scripts %}
<script src="/static/js/i18n.js"></script>
{% endblock %}
EOL

# 生成权限不足页面 模板
cat > app/templates/unauthorized.html << 'EOL'
{% extends "base.html" %}
{% block title %}
    <title>アクセス拒否</title>
{% endblock %}

{% block content %}
<div class="max-w-md w-full mx-auto glass-effect rounded-2xl p-8 shadow-lg space-y-6 fade-in">
    <h1 class="text-2xl font-bold text-red-600 mb-4 text-center">アクセス拒否</h1>
    <p class="mb-6 text-gray-700 text-center">このページを表示する権限がありません。</p>
    <a href="/login" class="bg-red-500 text-white px-4 py-2 rounded w-full text-center block">
        ログインページへ戻る
    </a>
</div>
{% endblock %}
EOL

echo "生成登出完成页面..."

# 生成登出完成页面 模板
cat > app/templates/logout.html << 'EOL'
{% extends "base.html" %}
{% block title %}
    <title>ログアウトしました</title>
{% endblock %}

{% block content %}
<div class="max-w-md w-full mx-auto glass-effect rounded-2xl p-8 shadow-lg space-y-6 fade-in">
    <h1 class="text-2xl font-bold mb-4 text-center">ログアウトしました</h1>
    <a href="/login" class="bg-blue-500 text-white px-4 py-2 rounded w-full text-center block">
        再ログイン
    </a>
</div>
{% endblock %}
EOL

echo "生成仪表盘页面..."

cat > app/templates/dashboard.html << 'EOL'
{% extends "base.html" %}
{% block title %}
    <title>ダッシュボード</title>
{% endblock %}

{% block content %}
<!-- 快速导航卡片 -->
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
    <a href="/m_users" class="nav-card bg-gradient-to-r from-blue-500 to-blue-600 rounded-xl p-6 text-white card-hover">
        <div class="flex items-center">
            <div class="bg-white/20 rounded-full p-3 mr-4">
                <i class="fas fa-users"></i>
            </div>
            <div>
                <h3 class="text-lg font-bold">ユーザー管理</h3>
                <p class="text-sm opacity-90">ユーザー情報の管理</p>
            </div>
        </div>
    </a>
    <a href="/t_work" class="nav-card bg-gradient-to-r from-green-500 to-green-600 rounded-xl p-6 text-white">
        <div class="flex items-center">
            <div class="bg-white/20 rounded-full p-3 mr-4">
                <i class="fas fa-tasks"></i>
            </div>
            <div>
                <h3 class="text-lg font-bold">作業管理</h3>
                <p class="text-sm opacity-90">作業情報の管理</p>
            </div>
        </div>
    </a>
    
    <a href="/m_customers" class="nav-card bg-gradient-to-r from-purple-500 to-purple-600 rounded-xl p-6 text-white">
        <div class="flex items-center">
            <div class="bg-white/20 rounded-full p-3 mr-4">
                <i class="fas fa-building"></i>
            </div>
            <div>
                <h3 class="text-lg font-bold">顧客管理</h3>
                <p class="text-sm opacity-90">顧客情報の管理</p>
            </div>
        </div>
    </a>
    
    <a href="/m_folder" class="nav-card bg-gradient-to-r from-indigo-500 to-indigo-600 rounded-xl p-6 text-white">
        <div class="flex items-center">
            <div class="bg-white/20 rounded-full p-3 mr-4">
                <i class="fas fa-folder"></i>
            </div>
            <div>
                <h3 class="text-lg font-bold">フォルダ管理</h3>
                <p class="text-sm opacity-90">フォルダ情報の管理</p>
            </div>
        </div>
    </a>

    <!-- 新增的导航卡片 -->
    <a href="/t_work_sub" class="nav-card bg-gradient-to-r from-red-500 to-red-600 rounded-xl p-6 text-white">
        <div class="flex items-center">
            <div class="bg-white/20 rounded-full p-3 mr-4">
                <i class="fas fa-list-ul"></i>
            </div>
            <div>
                <h3 class="text-lg font-bold">作業サブ管理</h3>
                <p class="text-sm opacity-90">作業詳細情報の管理</p>
            </div>
        </div>
    </a>

    <a href="/m_os" class="nav-card bg-gradient-to-r from-yellow-500 to-yellow-600 rounded-xl p-6 text-white">
        <div class="flex items-center">
            <div class="bg-white/20 rounded-full p-3 mr-4">
                <i class="fas fa-laptop"></i>
            </div>
            <div>
                <h3 class="text-lg font-bold">OS管理</h3>
                <p class="text-sm opacity-90">OS情報の管理</p>
            </div>
        </div>
    </a>

    <a href="/m_version" class="nav-card bg-gradient-to-r from-pink-500 to-pink-600 rounded-xl p-6 text-white">
        <div class="flex items-center">
            <div class="bg-white/20 rounded-full p-3 mr-4">
                <i class="fas fa-code-branch"></i>
            </div>
            <div>
                <h3 class="text-lg font-bold">バージョン管理</h3>
                <p class="text-sm opacity-90">バージョン情報の管理</p>
            </div>
        </div>
    </a>

    <a href="/m_workclass" class="nav-card bg-gradient-to-r from-teal-500 to-teal-600 rounded-xl p-6 text-white">
        <div class="flex items-center">
            <div class="bg-white/20 rounded-full p-3 mr-4">
                <i class="fas fa-tags"></i>
            </div>
            <div>
                <h3 class="text-lg font-bold">作業分類管理</h3>
                <p class="text-sm opacity-90">作業分類情報の管理</p>
            </div>
        </div>
    </a>

    <a href="/t_logs" class="nav-card bg-gradient-to-r from-gray-500 to-gray-600 rounded-xl p-6 text-white">
        <div class="flex items-center">
            <div class="bg-white/20 rounded-full p-3 mr-4">
                <i class="fas fa-history"></i>
            </div>
            <div>
                <h3 class="text-lg font-bold">ログ管理</h3>
                <p class="text-sm opacity-90">システムログの管理</p>
            </div>
        </div>
    </a>
</div>

<!-- 概览卡片 -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
    <div class="glass-effect rounded-xl p-6 card-hover fade-in">
        <div class="flex items-center">
            <div class="bg-blue-500 rounded-full p-3 mr-4 text-white">
                <i class="fas fa-users"></i>
            </div>
            <div>
                <p class="text-gray-600">ユーザー数</p>
                <h3 class="text-2xl font-bold text-gray-800" hx-get="/api/stats/users" hx-trigger="load">
                    <i class="fas fa-spinner fa-spin"></i>
                </h3>
            </div>
        </div>
    </div>

    <div class="glass-effect rounded-xl p-6 card-hover fade-in">
        <div class="flex items-center">
            <div class="bg-green-500 rounded-full p-3 mr-4 text-white">
                <i class="fas fa-tasks"></i>
            </div>
            <div>
                <p class="text-gray-600">作業数</p>
                <h3 class="text-2xl font-bold text-gray-800" hx-get="/api/stats/works" hx-trigger="load">
                    <i class="fas fa-spinner fa-spin"></i>
                </h3>
            </div>
        </div>
    </div>
    
    <div class="glass-effect rounded-xl p-6 card-hover fade-in">
        <div class="flex items-center">
            <div class="bg-purple-500 rounded-full p-3 mr-4 text-white">
                <i class="fas fa-folder"></i>
            </div>
            <div>
                <p class="text-gray-600">フォルダ数</p>
                <h3 class="text-2xl font-bold text-gray-800" hx-get="/api/stats/folders" hx-trigger="load">
                    <i class="fas fa-spinner fa-spin"></i>
                </h3>
            </div>
        </div>
    </div>
    
    <div class="glass-effect rounded-xl p-6 card-hover fade-in">
        <div class="flex items-center">
            <div class="bg-yellow-500 rounded-full p-3 mr-4 text-white">
                <i class="fas fa-chart-bar"></i>
            </div>
            <div>
                <p class="text-gray-600">アクティビティ</p>
                <h3 class="text-2xl font-bold text-gray-800" hx-get="/api/stats/activities" hx-trigger="load">
                    <i class="fas fa-spinner fa-spin"></i>
                </h3>
            </div>
        </div>
    </div>
</div>

<!-- 图表区域 -->
<div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
    <div class="glass-effect rounded-xl p-6 card-hover fade-in">
        <h2 class="text-lg font-bold text-gray-800 mb-4">
            <i class="fas fa-chart-pie mr-2"></i>作業分類分布
        </h2>
        <canvas id="workClassChart"></canvas>
    </div>
    <div class="glass-effect rounded-xl p-6 card-hover fade-in">
        <h2 class="text-lg font-bold text-gray-800 mb-4">
            <i class="fas fa-chart-line mr-2"></i>月別作業数
        </h2>
        <canvas id="monthlyWorkChart"></canvas>
    </div>
</div>

<!-- 最近的活動 -->
<div class="glass-effect rounded-xl p-6 card-hover fade-in">
    <h2 class="text-lg font-bold text-gray-800 mb-4">
        <i class="fas fa-history mr-2"></i>最近の活動
    </h2>
    <div hx-get="/api/activities/recent" hx-trigger="load">
        <div class="flex justify-center py-8">
            <i class="fas fa-spinner fa-spin text-2xl text-gray-500"></i>
        </div>
    </div>
</div>
{% endblock %}

{% block scripts %}
<script src="https://cdn.jsdelivr.net/npm/chart.js "></script>
<script>
document.addEventListener('DOMContentLoaded', function () {
    const workClassCtx = document.getElementById('workClassChart').getContext('2d');
    new Chart(workClassCtx, {
        type: 'pie',
        data: {
            labels: [],
            datasets: [{
                label: '作業分類',
                data: [],
                backgroundColor: ['#3B82F6', '#10B981', '#F59E0B', '#6366F1', '#EC4899']
            }]
        },
        options: { responsive: true, plugins: { legend: { position: 'right' } } }
    });

    const monthlyWorkCtx = document.getElementById('monthlyWorkChart').getContext('2d');
    new Chart(monthlyWorkCtx, {
        type: 'bar',
        data: {
            labels: ['1月','2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月'],
            datasets: [{ label: '作業数', data: [], backgroundColor: '#6366F1' }]
        },
        options: { scales: { y: { beginAtZero: true } } }
    });

    htmx.on('htmx:afterSwap', function(evt) {
        // 更新图表逻辑...
    });
});
</script>
{% endblock %}
EOL

echo "创建 国际化资源文件..."

echo "创建  en.json（英文）"
cat > app/static/locales/en.json << 'EOL'
{
  "title": "Login",
  "username": "Username",
  "password": "Password",
  "login": "Login",
  "logout": "Logout",
  "dashboard": "Dashboard",
  "users": "Users",
  "works": "Works",
  "customers": "Customers",
  "folders": "Folders"
}
EOL

echo "创建  ja.json（日文）"
cat > app/static/locales/ja.json << 'EOL'
{
  "title": "ログイン",
  "username": "ユーザーID",
  "password": "パスワード",
  "login": "ログイン",
  "logout": "ログアウト",
  "dashboard": "ダッシュボード",
  "users": "ユーザー管理",
  "works": "作業管理",
  "customers": "顧客管理",
  "folders": "フォルダ管理"
}
EOL

echo "添加 i18n JS 脚本"
cat > app/static/js/i18n.js << 'EOL'
const I18N = {
    currentLang: 'ja', // 默认语言
    messages: {},

    init() {
        const savedLang = localStorage.getItem('lang') || this.currentLang;
        this.currentLang = savedLang;
        this.loadMessages(savedLang);
        this.translatePage();
    },

    async loadMessages(lang) {
        try {
            const res = await fetch(`/static/locales/${lang}.json`);
            this.messages = await res.json();
        } catch (err) {
            console.error("Failed to load language file:", err);
        }
    },

    translatePage() {
        document.querySelectorAll('[data-i18n]').forEach(el => {
            const key = el.getAttribute('data-i18n');
            if (this.messages[key]) {
                el.textContent = this.messages[key];
            }
        });
    },

    setLanguage(lang) {
        this.currentLang = lang;
        localStorage.setItem('lang', lang);
        this.loadMessages(lang).then(() => this.translatePage());
    }
};

document.addEventListener('DOMContentLoaded', () => {
    I18N.init();
});
EOL

echo "生成数据库模型..."
cat > app/models/__init__.py << 'EOL'
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

load_dotenv()

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./sql_app.db")

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, 
    connect_args={"check_same_thread": False} if "sqlite" in SQLALCHEMY_DATABASE_URL else {}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 创建 所有表
def create_tables():
    from app.core.base_model import Base
    Base.metadata.create_all(bind=engine)
EOL

echo "生成主应用文件..."
cat > app/main.py << 'EOL'
from fastapi import FastAPI, Request, Form, Depends
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, RedirectResponse
import os
from dotenv import load_dotenv
from app.models import create_tables, get_db
from sqlalchemy.orm import Session
from starlette.middleware.sessions import SessionMiddleware
from app.models.m_users import MUsers
from app.models.t_work import TWork
from app.models.m_folder import MFolder
from app.models.m_workclass import MWorkclass
from app.models.t_logs import TLogs
from datetime import datetime, timedelta
import random

from fastapi.templating import Jinja2Templates
templates = Jinja2Templates(directory="app/templates")

# 加载环境变量
load_dotenv()

app = FastAPI(title="CRUD Application", version="1.0.0")
app.add_middleware(SessionMiddleware, secret_key="mysecretkey")

# 挂载静态文件
os.makedirs("app/static", exist_ok=True)
app.mount("/static", StaticFiles(directory="app/static"), name="static")

# 创建 数据库表
create_tables()

# 自动导入所有路由
def include_routers():
    routers_dir = "app/routers"
    if os.path.exists(routers_dir):
        for filename in os.listdir(routers_dir):
            if filename.endswith(".py") and filename != "__init__.py":
                try:
                    module_name = f"app.routers.{filename[:-3]}"
                    module = __import__(module_name, fromlist=["router"])
                    if hasattr(module, 'router'):
                        app.include_router(module.router)
                        print(f"Loaded router: {module_name}")
                except Exception as e:
                    print(f"Failed to load router {module_name}: {e}")

include_routers()

# @app.get("/")
# async def root():
#     return RedirectResponse(url="/docs")

@app.get("/")
async def root(request: Request):
    # 检查用户是否登录
    if not request.session.get("user_id"):
        return RedirectResponse(url="/login")
    return templates.TemplateResponse("dashboard.html", {"request": request})

# 仪表盘API
@app.get("/api/stats/users")
async def get_user_stats(db: Session = Depends(get_db)):
    count = db.query(MUsers).count()
    return HTMLResponse(f"{count}")

@app.get("/api/stats/works")
async def get_work_stats(db: Session = Depends(get_db)):
    count = db.query(TWork).count()
    return HTMLResponse(f"{count}")

@app.get("/api/stats/folders")
async def get_folder_stats(db: Session = Depends(get_db)):
    count = db.query(MFolder).count()
    return HTMLResponse(f"{count}")

@app.get("/api/stats/activities")
async def get_activity_stats(db: Session = Depends(get_db)):
    count = db.query(TLogs).count()
    return HTMLResponse(f"{count}")

@app.get("/api/activities/recent")
async def get_recent_activities(db: Session = Depends(get_db)):
    activities = db.query(TLogs).order_by(TLogs.created.desc()).limit(5).all()
    
    if not activities:
        return HTMLResponse("<p class='text-gray-500 text-center py-4'>最近の活動はありません</p>")
    
    html = """
    <div class="space-y-4">
    """
    
    for activity in activities:
        html += f"""
        <div class="flex items-start border-b border-gray-100 pb-4">
            <div class="bg-purple-100 p-2 rounded-lg mr-4">
                <i class="fas fa-history text-purple-600"></i>
            </div>
            <div>
                <p class="font-medium text-gray-800">{activity.work_content or 'アクティビティ'}</p>
                <p class="text-sm text-gray-500">
                    {activity.user_name or 'システム'} - 
                    {activity.created.strftime('%Y/%m/%d %H:%M') if activity.created else ''}
                </p>
            </div>
        </div>
        """
    
    html += "</div>"
    return HTMLResponse(html)

@app.get("/api/charts/data")
async def get_chart_data(db: Session = Depends(get_db)):
    # 模拟作业分类数据
    work_classes = db.query(MWorkclass).all()
    work_class_data = {
        "labels": [wc.name for wc in work_classes],
        "data": [random.randint(5, 20) for _ in work_classes]
    }
    
    # 模拟月度作业数据
    months = [f"{i}月" for i in range(1, 13)]
    monthly_work_data = {
        "labels": months,
        "data": [random.randint(10, 50) for _ in months]
    }
    
    return {
        "workClass": work_class_data,
        "monthlyWork": monthly_work_data
    }
    
@app.get("/login", response_class=HTMLResponse)
async def login_form(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})

@app.post("/login")
async def login(request: Request, userid: str = Form(...), passwd: str = Form(...), db: Session = Depends(get_db)):
    user = db.query(MUsers).filter(MUsers.userid == userid, MUsers.passwd == passwd).first()
    if not user:
        return {"error": "Invalid credentials"}
    request.session["user_id"] = user.id
    return RedirectResponse(url="/", status_code=302)

@app.get("/logout")
async def logout(request: Request):
    request.session.clear()
    return RedirectResponse(url="/", status_code=302)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOL

echo "生成启动脚本..."
cat > run.sh << 'EOL'
#!/bin/bash
source venv/bin/activate
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
EOL

chmod +x run.sh

echo "生成.env文件..."
cat > .env << 'EOL'
DATABASE_URL=sqlite:///./sql_app.db
EOL

echo "生成init文件..."
touch app/__init__.py
touch app/core/__init__.py
touch app/routers/__init__.py

echo "运行生成脚本..."
python scripts/generate.py

echo "项目初始化完成！"
echo "启动项目:"
echo "1. cd $PROJECT_NAME"
echo "2. source venv/bin/activate"  
echo "3. ./run.sh"
echo "4. 访问 http://localhost:8000 查看API文档"