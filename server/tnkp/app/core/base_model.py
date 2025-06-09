from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer

Base = declarative_base()

'''
class BaseModel(Base):
    __abstract__ = True
    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    
    @classmethod
    def get_router(cls):
        from app.core.base_crud import BaseCRUD
        return BaseCRUD.create_router(cls)
'''

class BaseModel(Base):
    __abstract__ = True

    @classmethod
    def get_primary_key(cls):
        """获取主键字段名"""
        for col in cls.__table__.columns:
            if col.primary_key:
                return col.name
        return "id"  # 兜底

    @classmethod
    def get_router(cls):
        from app.core.base_crud import BaseCRUD
        return BaseCRUD.create_router(cls)
