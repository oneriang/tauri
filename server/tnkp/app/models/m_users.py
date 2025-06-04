
from sqlalchemy import Column, Integer, String
from app.core.base_model import BaseModel

import yaml
import os

# 获取当前模块路径
current_dir = os.getcwd()
config_path = os.path.join(current_dir, 'app', 'config', 'models', 'm_users.yaml')

with open(config_path, 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

class MUsers(BaseModel):
    __tablename__ = "m_users"
    
    userid = Column(String(50))
    passwd = Column(String(100))
    fname = Column(String(50))
    lname = Column(String(50))
    permission = Column(Integer)
    facilitator = Column(Integer)
    delflg = Column(Integer)

