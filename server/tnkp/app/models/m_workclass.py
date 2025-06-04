
from sqlalchemy import Column, String
from app.core.base_model import BaseModel

import yaml
import os

# 获取当前模块路径
current_dir = os.getcwd()
config_path = os.path.join(current_dir, 'app', 'config', 'models', 'm_workclass.yaml')

with open(config_path, 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

class MWorkclass(BaseModel):
    __tablename__ = "m_workclass"
    
    name = Column(String(50))
    comment = Column(String(200))

