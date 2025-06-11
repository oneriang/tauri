
from sqlalchemy import Column, Integer, String
from app.core.base_model import BaseModel

import yaml
import os

# 获取当前模块路径
current_dir = os.getcwd()
config_path = os.path.join(current_dir, 'app', 'config', 'models', 'm_version.yaml')

with open(config_path, 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

class MVersion(BaseModel):
    __tablename__ = "m_version"
    __categoryname__ = "master"
    __is_view__ = False

    id = Column(Integer, primary_key=True)
    name = Column(String(50))
    comment = Column(String(200))
    delflg = Column(Integer, nullable=True, default=0)
    sort = Column(Integer)

@classmethod
async def save_via_view(cls, form_data, db):
    #このビューの保存は実際のテーブルに書き込みます
    raise NotImplementedError("save_via_view is not implemented")

