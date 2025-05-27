
from fastapi import APIRouter
from app.models.t_logs import TLogs

# 创建 路由实例
t_logs_model = TLogs
router = t_logs_model.get_router()
