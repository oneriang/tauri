
from fastapi import APIRouter
from app.models.m_workclass import MWorkclass

# 创建 路由实例
m_workclass_model = MWorkclass
router = m_workclass_model.get_router()
