
from sqlalchemy import Column, DateTime, Integer, String, Text
from app.core.base_model import BaseModel

class TLogs(BaseModel):
    __tablename__ = "t_logs"
    
    user_id = Column(Integer, nullable=True)
    user_name = Column(String(50), nullable=True)
    folder_name = Column(String(100), nullable=True)
    work_content = Column(Text, nullable=True)
    result = Column(Text, nullable=True)
    created = Column(DateTime, nullable=True, default='func.now()')

    __fields__ = [   {   'default': None,
        'html_type': 'number',
        'label': 'ユーザーID',
        'name': 'user_id',
        'required': False,
        'type': 'Integer'},
    {   'default': None,
        'html_type': 'text',
        'label': 'ユーザー名',
        'name': 'user_name',
        'required': False,
        'type': 'String(50)'},
    {   'default': None,
        'html_type': 'text',
        'label': 'フォルダ名',
        'name': 'folder_name',
        'required': False,
        'type': 'String(100)'},
    {   'default': None,
        'html_type': 'textarea',
        'label': '作業内容',
        'name': 'work_content',
        'required': False,
        'type': 'Text'},
    {   'default': None,
        'html_type': 'textarea',
        'label': '結果',
        'name': 'result',
        'required': False,
        'type': 'Text'},
    {   'default': 'func.now()',
        'html_type': 'date',
        'label': '作成日時',
        'name': 'created',
        'required': False,
        'type': 'DateTime'}]
