
from fastapi import APIRouter
from app.models.m_customers import MCustomers

# 创建 路由实例
m_customers_model = MCustomers
router = m_customers_model.get_router()
