
from fastapi import APIRouter
from app.models.m_users import MUsers

# 创建 路由实例
m_users_model = MUsers
router = m_users_model.get_router()
