
from sqlalchemy import Column, String
from app.core.base_model import BaseModel

class MWorkclass(BaseModel):
    __tablename__ = "m_workclass"
    
    name = Column(String(50))
    comment = Column(String(200))

    __fields__ = [   {   'default': None,
        'html_type': 'text',
        'label': '分類名',
        'name': 'name',
        'required': True,
        'type': 'String(50)'},
    {   'default': None,
        'html_type': 'text',
        'label': 'コメント',
        'name': 'comment',
        'required': True,
        'type': 'String(200)'}]
