
from sqlalchemy import Column, DateTime, Integer, String
from app.core.base_model import BaseModel
from app.models.m_users import MUsers

import yaml
import os

# 获取当前模块路径
current_dir = os.getcwd()
config_path = os.path.join(current_dir, 'app', 'config', 'models', 'v_user_activities.yaml')

with open(config_path, 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

class VUserActivities(BaseModel):
    __tablename__ = "v_user_activities"
    __categoryname__ = "view"
    __is_view__ = True

    user_id = Column(Integer, primary_key=True)
    user_name = Column(String(100))
    work_count = Column(Integer)
    last_activity = Column(DateTime)

# @classmethod
# async def save_via_view(cls, form_data, db):
#     #このビューの保存は実際のテーブルに書き込みます
#     raise NotImplementedError("save_via_view is not implemented")

    @classmethod
    async def save_via_view(cls, form_data, db):
        user_id = form_data.get("user_id")
        if not user_id:
            raise ValueError("ユーザーIDは必須です")

        user = db.query(MUsers).filter(MUsers.id == user_id).first()
        if not user:
            raise ValueError(f"ユーザー {user_id} が見つかりません")

        # 備考だけ更新（例）
        user.lname = form_data.get("user_name")
        db.commit()
