
from fastapi import APIRouter
from app.models.t_work import TWork

# 创建 路由实例
t_work_model = TWork
router = t_work_model.get_router()
