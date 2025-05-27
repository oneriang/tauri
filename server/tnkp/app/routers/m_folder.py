
from fastapi import APIRouter
from app.models.m_folder import MFolder

# 创建 路由实例
m_folder_model = MFolder
router = m_folder_model.get_router()
