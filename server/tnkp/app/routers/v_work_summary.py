
from fastapi import APIRouter
from app.models.v_work_summary import VWorkSummary

# 创建 路由实例
v_work_summary_model = VWorkSummary
router = v_work_summary_model.get_router()
