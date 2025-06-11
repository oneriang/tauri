
from sqlalchemy import Column, Integer, String
from app.core.base_model import BaseModel

import yaml
import os

# 获取当前模块路径
current_dir = os.getcwd()
config_path = os.path.join(current_dir, 'app', 'config', 'models', 't_work.yaml')

with open(config_path, 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

class TWork(BaseModel):
    __tablename__ = "t_work"
    __categoryname__ = "master"
    __is_view__ = False

    id = Column(Integer, primary_key=True)
    customer_id = Column(Integer)
    slip_number = Column(String(50))
    title = Column(String(200))
    facilitator_id = Column(String(50))
    version_id = Column(Integer)
    os_id = Column(Integer)
    folder_id = Column(Integer)
    delflg = Column(Integer, nullable=True, default=0)
    mountflg = Column(Integer, nullable=True, default=0)
    mountflgstr = Column(String(10), nullable=True)

@classmethod
async def save_via_view(cls, form_data, db):
    #このビューの保存は実際のテーブルに書き込みます
    raise NotImplementedError("save_via_view is not implemented")

