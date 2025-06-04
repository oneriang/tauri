
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
    
    name = Column(String(50))
    comment = Column(String(200))
    delflg = Column(Integer, nullable=True, default=0)
    sort = Column(Integer)

