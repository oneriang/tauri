
from fastapi import APIRouter
from app.models.m_os import MOs

# 创建 路由实例
m_os_model = MOs
router = m_os_model.get_router()
