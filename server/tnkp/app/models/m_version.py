
from sqlalchemy import Column, Integer, String
from app.core.base_model import BaseModel

class MVersion(BaseModel):
    __tablename__ = "m_version"
    
    name = Column(String(50))
    comment = Column(String(200))
    delflg = Column(Integer, nullable=True, default=0)
    sort = Column(Integer)

    __fields__ = [   {   'default': None,
        'html_type': 'text',
        'label': 'バージョン名',
        'name': 'name',
        'required': True,
        'type': 'String(50)'},
    {   'default': None,
        'html_type': 'text',
        'label': 'コメント',
        'name': 'comment',
        'required': True,
        'type': 'String(200)'},
    {   'default': 0,
        'html_type': 'number',
        'label': '削除フラグ',
        'name': 'delflg',
        'required': False,
        'type': 'Integer'},
    {   'default': None,
        'html_type': 'number',
        'label': 'ソート順',
        'name': 'sort',
        'required': True,
        'type': 'Integer'}]
