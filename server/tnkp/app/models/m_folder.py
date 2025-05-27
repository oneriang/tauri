
from sqlalchemy import Column, Integer, String
from app.core.base_model import BaseModel

class MFolder(BaseModel):
    __tablename__ = "m_folder"
    
    name = Column(String(100))
    ip = Column(String(50))
    path = Column(String(200))
    admin = Column(Integer)
    user_name = Column(String(50))
    passwd = Column(String(100))
    delflg = Column(Integer, nullable=True, default=0)

    __fields__ = [   {   'default': None,
        'html_type': 'text',
        'label': 'フォルダ名',
        'name': 'name',
        'required': True,
        'type': 'String(100)'},
    {   'default': None,
        'html_type': 'text',
        'label': 'IPアドレス',
        'name': 'ip',
        'required': True,
        'type': 'String(50)'},
    {   'default': None,
        'html_type': 'text',
        'label': 'パス',
        'name': 'path',
        'required': True,
        'type': 'String(200)'},
    {   'default': None,
        'html_type': 'number',
        'label': '管理者',
        'name': 'admin',
        'required': True,
        'type': 'Integer'},
    {   'default': None,
        'html_type': 'text',
        'label': 'ユーザー名',
        'name': 'user_name',
        'required': True,
        'type': 'String(50)'},
    {   'default': None,
        'html_type': 'text',
        'label': 'パスワード',
        'name': 'passwd',
        'required': True,
        'type': 'String(100)'},
    {   'default': 0,
        'html_type': 'number',
        'label': '削除フラグ',
        'name': 'delflg',
        'required': False,
        'type': 'Integer'}]
