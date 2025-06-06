
from sqlalchemy import Column, Integer, String
from app.core.base_model import BaseModel

import yaml
import os

# 获取当前模块路径
current_dir = os.getcwd()
config_path = os.path.join(current_dir, 'app', 'config', 'models', 'm_folder.yaml')

with open(config_path, 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

class MFolder(BaseModel):
    __tablename__ = "m_folder"
    
    name = Column(String(100))
    ip = Column(String(50))
    path = Column(String(200))
    admin = Column(Integer)
    user_name = Column(String(50))
    passwd = Column(String(100))
    delflg = Column(Integer, nullable=True, default=0)

