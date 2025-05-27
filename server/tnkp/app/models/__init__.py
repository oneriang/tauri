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

# 创建 所有表
def create_tables():
    from app.core.base_model import Base
    Base.metadata.create_all(bind=engine)

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
