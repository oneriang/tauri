
from sqlalchemy import Column, Integer, String
from app.core.base_model import BaseModel

class MUsers(BaseModel):
    __tablename__ = "m_users"
    
    userid = Column(String(50))
    passwd = Column(String(100))
    fname = Column(String(50))
    lname = Column(String(50))
    permission = Column(Integer)
    facilitator = Column(Integer)
    delflg = Column(Integer)

    __fields__ = [   {   'default': None,
        'html_type': 'text',
        'label': 'ユーザーID',
        'name': 'userid',
        'required': True,
        'type': 'String(50)'},
    {   'default': None,
        'html_type': 'text',
        'label': 'パスワード',
        'name': 'passwd',
        'required': True,
        'type': 'String(100)'},
    {   'default': None,
        'html_type': 'text',
        'label': '名前',
        'name': 'fname',
        'required': True,
        'type': 'String(50)'},
    {   'default': None,
        'html_type': 'text',
        'label': '姓',
        'name': 'lname',
        'required': True,
        'type': 'String(50)'},
    {   'default': None,
        'html_type': 'number',
        'label': '権限',
        'name': 'permission',
        'required': True,
        'type': 'Integer'},
    {   'default': None,
        'html_type': 'number',
        'label': '進行者',
        'name': 'facilitator',
        'required': True,
        'type': 'Integer'},
    {   'default': None,
        'html_type': 'number',
        'label': '削除フラグ',
        'name': 'delflg',
        'required': True,
        'type': 'Integer'}]
