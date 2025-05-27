from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer

Base = declarative_base()

class BaseModel(Base):
    __abstract__ = True
    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    
    @classmethod
    def get_router(cls):
        from app.core.base_crud import BaseCRUD
        return BaseCRUD.create_router(cls)
