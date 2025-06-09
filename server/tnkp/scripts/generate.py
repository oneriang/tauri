import os
from pathlib import Path
import pprint

import yaml

# 表定义配置（日语字段说明）
TABLES = {
    "t_work": {
        "fields": [
            {"name": "id", "type": "Integer", "required": True, "primary_key": True, "label": "ID"},
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
            {"name": "id", "type": "Integer", "required": True, "primary_key": True, "label": "ID"},
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
            {"name": "id", "type": "Integer", "required": True, "primary_key": True, "label": "ID"},
            {"name": "code", "type": "String(20)", "required": True, "default": None, "label": "顧客コード"},
            {"name": "name", "type": "String(100)", "required": True, "default": None, "label": "顧客名"},
            {"name": "delflg", "type": "Integer", "required": True, "default": None, "label": "削除フラグ"}
        ]
    },
    "m_folder": {
        "name": "フォルダマスタ",
        "description": "フォルダ情報を管理",
        "fields": [
            {"name": "id", "type": "Integer", "required": True, "primary_key": True, "label": "ID"},
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
            {"name": "id", "type": "Integer", "required": True, "primary_key": True, "label": "ID"},
            {"name": "name", "type": "String(50)", "required": True, "default": None, "label": "OS名"},
            {"name": "comment", "type": "String(200)", "required": True, "default": None, "label": "コメント"},
            {"name": "delflg", "type": "Integer", "required": False, "default": 0, "label": "削除フラグ"}
        ]
    },
    "m_users": {
        "name": "ユーザーマスタ",
        "description": "ユーザー情報を管理",
        "fields": [
            {"name": "id", "type": "Integer", "required": True, "primary_key": True, "label": "ID"},
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
            {"name": "id", "type": "Integer", "required": True, "primary_key": True, "label": "ID"},
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
            {"name": "id", "type": "Integer", "required": True, "primary_key": True, "label": "ID"},
            {"name": "name", "type": "String(50)", "required": True, "default": None, "label": "分類名"},
            {"name": "comment", "type": "String(200)", "required": True, "default": None, "label": "コメント"}
        ]
    },
    "t_logs": {
        "name": "ログテーブル",
        "description": "システムログを管理",
        "fields": [
            {"name": "id", "type": "Integer", "required": True, "primary_key": True, "label": "ID"},
            {"name": "user_id", "type": "Integer", "required": False, "default": None, "label": "ユーザーID"},
            {"name": "user_name", "type": "String(50)", "required": False, "default": None, "label": "ユーザー名"},
            {"name": "folder_name", "type": "String(100)", "required": False, "default": None, "label": "フォルダ名"},
            {"name": "work_content", "type": "Text", "required": False, "default": None, "label": "作業内容"},
            {"name": "result", "type": "Text", "required": False, "default": None, "label": "結果"},
            {"name": "created", "type": "DateTime", "required": False, "default": "func.now()", "label": "作成日時"}
        ]
    }
}

# 在TABLES字典后添加VIEWS字典
VIEWS = {
    "v_work_summary": {
        "name": "作業サマリービュー",
        "description": "作業情報のサマリービュー",
        "fields": [
            {"name": "work_id", "type": "Integer", "primary_key": True, "label": "作業ID"},
            {"name": "customer_name", "type": "String(100)", "label": "顧客名"},
            {"name": "slip_number", "type": "String(50)", "label": "伝票番号"},
            {"name": "title", "type": "String(200)", "label": "タイトル"},
            {"name": "facilitator_name", "type": "String(50)", "label": "進行者"},
            {"name": "work_count", "type": "Integer", "label": "作業数"},
            {"name": "last_updated", "type": "DateTime", "label": "最終更新日時"}
        ]
    },
    "v_user_activities": {
        "name": "ユーザー活動ビュー",
        "description": "ユーザーの活動状況ビュー",
        "fields": [
            {"name": "user_id", "type": "Integer", "primary_key": True, "label": "ユーザーID"},
            {"name": "user_name", "type": "String(100)", "label": "ユーザー名"},
            {"name": "work_count", "type": "Integer", "label": "作業数"},
            {"name": "last_activity", "type": "DateTime", "label": "最終活動日時"}
        ]
    }
}

#  模板定义
TEMPLATES = {
    "model.py.j2": """
from sqlalchemy import Column, {field_types}
from app.core.base_model import BaseModel

import yaml
import os

# 获取当前模块路径
current_dir = os.getcwd()
config_path = os.path.join(current_dir, 'app', 'config', 'models', '{table_name}.yaml')

with open(config_path, 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

class {model_name}(BaseModel):
    __tablename__ = "{table_name}"
    __is_view__ = {is_view}

{columns}

@classmethod
async def save_via_view(cls, form_data, db):
    #このビューの保存は実際のテーブルに書き込みます
    raise NotImplementedError("save_via_view is not implemented")

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

def generate_yaml(table_name, config):
    """生成YAML配置文件"""
    model_name = ''.join([word.capitalize() for word in table_name.split('_')])
    data = {
        "model": {
            "name": model_name,
            "table_name": table_name,
            "fields": {}
        }
    }

    for field in config["fields"]:
        # name = field.pop("name")
        name = field["name"]
        data["model"]["fields"][name] = field

    config_dir = Path("app/config/models")
    config_dir.mkdir(parents=True, exist_ok=True)
    with open(config_dir / f"{table_name}.yaml", "w", encoding="utf-8") as f:
        yaml.dump(data, f, allow_unicode=True, sort_keys=False)


# 修改generate函数
def generate():
    # 生成表模型和视图模型
    for table_name, config in {**TABLES, **VIEWS}.items():
        is_view = table_name in VIEWS  # 判断是否是视图
        
        generate_yaml(table_name, config)
        
        model_name = ''.join([word.capitalize() for word in table_name.split('_')])
        
        # 生成字段定义
        columns = []
        for field in config["fields"]:
            column_def = f"    {field['name']} = Column({field['type']}"
            
            if field.get("primary_key"):
                column_def += ", primary_key=True"
    
            if not is_view and not field.get('required', True):
                column_def += ", nullable=True"
            if not is_view and field.get('default') is not None:
                if isinstance(field['default'], str):
                    column_def += f", default='{field['default']}'"
                else:
                    column_def += f", default={field['default']}"
            column_def += ")"
            columns.append(column_def)
            
            field['html_type'] = get_field_type(field)
            
            if 'widget_type' in field:
                field['widget_type'] = field['widget_type']
            if 'choices' in field:
                field['choices'] = field['choices']
                
        context = {
            "table_name": table_name,
            "model_name": model_name,
            "is_view": is_view,  # 传递给模板
            "fields": pprint.pformat(config["fields"], indent=4, width=100),
            "field_types": ", ".join(get_unique_types(config["fields"])),
            "columns": "\n".join(columns)
        }

        # 生成所有模板文件
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
        for table_name in {**TABLES, **VIEWS}.keys():
            model_name = ''.join([word.capitalize() for word in table_name.split('_')])
            f.write(f"from .{table_name} import {model_name}\n")
    
    with open("app/routers/__init__.py", "w", encoding='utf-8') as f:
        f.write("# Routers module\n")

if __name__ == "__main__":
    generate()
    print("代码生成完成！")
