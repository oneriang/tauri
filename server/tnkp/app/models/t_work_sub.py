
from sqlalchemy import Column, DateTime, Integer, Text
from app.core.base_model import BaseModel

import yaml
import os

# 获取当前模块路径
current_dir = os.getcwd()
config_path = os.path.join(current_dir, 'app', 'config', 'models', 't_work_sub.yaml')

with open(config_path, 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

class TWorkSub(BaseModel):
    __tablename__ = "t_work_sub"
    
    work_id = Column(Integer)
    workclass_id = Column(Integer)
    urtime = Column(DateTime, nullable=True)
    mtime = Column(DateTime, nullable=True)
    durtime = Column(DateTime, nullable=True)
    comment = Column(Text)
    working_user_id = Column(Integer)
    delflg = Column(Integer)

