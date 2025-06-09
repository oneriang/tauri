
from sqlalchemy import Column, DateTime, Integer, String, Text
from app.core.base_model import BaseModel

import yaml
import os

# 获取当前模块路径
current_dir = os.getcwd()
config_path = os.path.join(current_dir, 'app', 'config', 'models', 't_logs.yaml')

with open(config_path, 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

class TLogs(BaseModel):
    __tablename__ = "t_logs"
    __is_view__ = False

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, nullable=True)
    user_name = Column(String(50), nullable=True)
    folder_name = Column(String(100), nullable=True)
    work_content = Column(Text, nullable=True)
    result = Column(Text, nullable=True)
    created = Column(DateTime, nullable=True, default='func.now()')

@classmethod
async def save_via_view(cls, form_data, db):
    #このビューの保存は実際のテーブルに書き込みます
    raise NotImplementedError("save_via_view is not implemented")

