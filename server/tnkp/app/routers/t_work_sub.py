
from fastapi import APIRouter
from app.models.t_work_sub import TWorkSub

# 创建 路由实例
t_work_sub_model = TWorkSub
router = t_work_sub_model.get_router()
