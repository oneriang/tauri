
from fastapi import APIRouter
from app.models.v_user_activities import VUserActivities

# 创建 路由实例
v_user_activities_model = VUserActivities
router = v_user_activities_model.get_router()
