from fastapi import FastAPI, Request, Form, Depends
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.exceptions import HTTPException
import os
from dotenv import load_dotenv
from app.models import create_tables, create_views, get_db
from sqlalchemy.orm import Session
from starlette.middleware.sessions import SessionMiddleware
from app.models.m_users import MUsers
from app.models.t_work import TWork
from app.models.m_folder import MFolder
from app.models.m_workclass import MWorkclass
from app.models.t_logs import TLogs
from datetime import datetime, timedelta
import random

from fastapi.templating import Jinja2Templates
templates = Jinja2Templates(directory="app/templates")

# 加载环境变量
load_dotenv()

app = FastAPI(title="CRUD Application", version="1.0.0")
app.add_middleware(SessionMiddleware, secret_key="mysecretkey")

# 挂载静态文件
os.makedirs("app/static", exist_ok=True)
app.mount("/static", StaticFiles(directory="app/static"), name="static")

# 创建 数据库表
create_tables()

create_views()

# 自动导入所有路由
def include_routers():
    routers_dir = "app/routers"
    if os.path.exists(routers_dir):
        for filename in os.listdir(routers_dir):
            if filename.endswith(".py") and filename != "__init__.py":
                try:
                    module_name = f"app.routers.{filename[:-3]}"
                    module = __import__(module_name, fromlist=["router"])
                    if hasattr(module, 'router'):
                        app.include_router(module.router)
                        print(f"Loaded router: {module_name}")
                except Exception as e:
                    print(f"Failed to load router {module_name}: {e}")

include_routers()

def build_breadcrumbs(current_label, icon, tail=False):
    return [
        {"title": "Home", "href": "/", "icon": "fas fa-home"},
        {"title": current_label, "icon": icon} if tail else None
    ]

from app.utils.yaml_loader import load_yaml_config

@app.exception_handler(401)
async def redirect_to_login(request: Request, exc: HTTPException):
    return RedirectResponse(url="/login")  # 

@app.get("/")
async def dashboard(request: Request, db: Session = Depends(get_db)):
    # 获取用户信息
    if not request.session.get("user_id"):
        return RedirectResponse(url="/login")

    # 加载仪表盘配置
    dashboard_config = load_yaml_config("dashboard.yaml")

    # 合并数据
    context = {
        "request": request,
        "dashboard": dashboard_config["dashboard"],
        "breadcrumbs": build_breadcrumbs("一覧", "fas fa-list", True)
    }

    return templates.TemplateResponse("dashboard.html", context)

@app.get("/master")
async def master(request: Request, db: Session = Depends(get_db)):
    # 获取用户信息
    if not request.session.get("user_id"):
        return RedirectResponse(url="/login")

    # 加载仪表盘配置
    master_config = load_yaml_config("master.yaml")

    # 合并数据
    context = {
        "request": request,
        "master": master_config["master"],
        "breadcrumbs": build_breadcrumbs("マスター", "fas fa-list", True)
    }

    return templates.TemplateResponse("master.html", context)

@app.get("/view")
async def view(request: Request, db: Session = Depends(get_db)):
    # 获取用户信息
    if not request.session.get("user_id"):
        return RedirectResponse(url="/login")

    # 加载仪表盘配置
    view_config = load_yaml_config("view.yaml")

    # 合并数据
    context = {
        "request": request,
        "view": view_config["view"],
        "breadcrumbs": build_breadcrumbs("ビュー", "fas fa-list", True)
    }

    return templates.TemplateResponse("view.html", context)

# 仪表盘API
@app.get("/api/stats/users")
async def get_user_stats(db: Session = Depends(get_db)):
    count = db.query(MUsers).count()
    return HTMLResponse(f"{count}")

@app.get("/api/stats/works")
async def get_work_stats(db: Session = Depends(get_db)):
    count = db.query(TWork).count()
    return HTMLResponse(f"{count}")

@app.get("/api/stats/folders")
async def get_folder_stats(db: Session = Depends(get_db)):
    count = db.query(MFolder).count()
    return HTMLResponse(f"{count}")

@app.get("/api/stats/activities")
async def get_activity_stats(db: Session = Depends(get_db)):
    count = db.query(TLogs).count()
    return HTMLResponse(f"{count}")

@app.get("/api/activities/recent")
async def get_recent_activities(db: Session = Depends(get_db)):
    activities = db.query(TLogs).order_by(TLogs.created.desc()).limit(5).all()
    
    if not activities:
        return HTMLResponse("<p class='text-gray-500 text-center py-4'>最近の活動はありません</p>")
    
    html = """
    <div class="space-y-4">
    """
    
    for activity in activities:
        html += f"""
        <div class="flex items-start border-b border-gray-100 pb-4">
            <div class="bg-purple-100 p-2 rounded-lg mr-4">
                <i class="fas fa-history text-purple-600"></i>
            </div>
            <div>
                <p class="font-medium text-gray-800">{activity.work_content or 'アクティビティ'}</p>
                <p class="text-sm text-gray-500">
                    {activity.user_name or 'システム'} - 
                    {activity.created.strftime('%Y/%m/%d %H:%M') if activity.created else ''}
                </p>
            </div>
        </div>
        """
    
    html += "</div>"
    return HTMLResponse(html)

@app.get("/api/charts/data")
async def get_chart_data(db: Session = Depends(get_db)):
    # 模拟作业分类数据
    work_classes = db.query(MWorkclass).all()
    work_class_data = {
        "labels": [wc.name for wc in work_classes],
        "data": [random.randint(5, 20) for _ in work_classes]
    }
    
    # 模拟月度作业数据
    months = [f"{i}月" for i in range(1, 13)]
    monthly_work_data = {
        "labels": months,
        "data": [random.randint(10, 50) for _ in months]
    }
    
    return {
        "workClass": work_class_data,
        "monthlyWork": monthly_work_data
    }
    
@app.get("/login", response_class=HTMLResponse)
async def login_form(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})

@app.post("/login")
async def login(request: Request, userid: str = Form(...), passwd: str = Form(...), db: Session = Depends(get_db)):
    user = db.query(MUsers).filter(MUsers.userid == userid, MUsers.passwd == passwd).first()
    if not user:
        return {"error": "Invalid credentials"}
    request.session["user_id"] = user.id
    return RedirectResponse(url="/", status_code=302)

@app.get("/logout")
async def logout(request: Request):
    request.session.clear()
    return RedirectResponse(url="/", status_code=302)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
