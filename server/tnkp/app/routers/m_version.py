
from fastapi import APIRouter
from app.models.m_version import MVersion

# 创建 路由实例
m_version_model = MVersion
router = m_version_model.get_router()
