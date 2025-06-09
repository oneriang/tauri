from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

load_dotenv()

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./sql_app.db")

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, 
    connect_args={"check_same_thread": False} if "sqlite" in SQLALCHEMY_DATABASE_URL else {}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_views():
    """创建SQL视图"""
    from sqlalchemy import text
    
    # 确保表已存在
    create_tables()
    
    db = SessionLocal()
    try:
        # 创建作业摘要视图
        db.execute(text("""
        CREATE VIEW IF NOT EXISTS v_work_summary AS
        SELECT 
            w.id AS work_id,
            c.name AS customer_name,
            w.slip_number,
            w.title,
            u.fname || ' ' || u.lname AS facilitator_name,
            COUNT(ws.id) AS work_count,
            MAX(ws.mtime) AS last_updated
        FROM t_work w
        LEFT JOIN m_customers c ON w.customer_id = c.id
        LEFT JOIN m_users u ON w.facilitator_id = u.id
        LEFT JOIN t_work_sub ws ON ws.work_id = w.id
        GROUP BY w.id, c.name, w.slip_number, w.title, u.fname, u.lname
        """))
        
        # 创建用户活动视图
        db.execute(text("""
        CREATE VIEW IF NOT EXISTS v_user_activities AS
        SELECT 
            u.id AS user_id,
            u.fname || ' ' || u.lname AS user_name,
            COUNT(DISTINCT w.id) AS work_count,
            MAX(l.created) AS last_activity
        FROM m_users u
        LEFT JOIN t_work w ON w.facilitator_id = u.id
        LEFT JOIN t_logs l ON l.user_id = u.id
        GROUP BY u.id, u.fname, u.lname
        """))
        
        db.commit()
    except Exception as e:
        db.rollback()
        print(f"Error creating views: {e}")
    finally:
        db.close()

# 创建 所有表
def create_tables():
    from app.core.base_model import Base
    
    tables_to_create = [
        table for name, table in Base.metadata.tables.items()
        if name.startswith("v_") == False
    ]
    print("🛠️ Creating tables:", [t.name for t in tables_to_create])

    Base.metadata.create_all(bind=engine, tables=tables_to_create)

# Import all models
from .t_work import TWork
from .t_work_sub import TWorkSub
from .m_customers import MCustomers
from .m_folder import MFolder
from .m_os import MOs
from .m_users import MUsers
from .m_version import MVersion
from .m_workclass import MWorkclass
from .t_logs import TLogs
from .v_work_summary import VWorkSummary
from .v_user_activities import VUserActivities
