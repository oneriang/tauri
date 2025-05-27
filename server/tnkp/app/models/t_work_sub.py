
from sqlalchemy import Column, DateTime, Integer, Text
from app.core.base_model import BaseModel

class TWorkSub(BaseModel):
    __tablename__ = "t_work_sub"
    
    work_id = Column(Integer)
    workclass_id = Column(Integer)
    urtime = Column(DateTime, nullable=True)
    mtime = Column(DateTime, nullable=True)
    durtime = Column(DateTime, nullable=True)
    comment = Column(Text)
    working_user_id = Column(Integer)
    delflg = Column(Integer)

    __fields__ = [   {   'default': None,
        'html_type': 'number',
        'label': '作業ID',
        'name': 'work_id',
        'required': True,
        'type': 'Integer'},
    {   'default': None,
        'html_type': 'number',
        'label': '作業分類ID',
        'name': 'workclass_id',
        'required': True,
        'type': 'Integer'},
    {   'default': None,
        'html_type': 'date',
        'label': '開始時間',
        'name': 'urtime',
        'required': False,
        'type': 'DateTime'},
    {   'default': None,
        'html_type': 'date',
        'label': '変更時間',
        'name': 'mtime',
        'required': False,
        'type': 'DateTime'},
    {   'default': None,
        'html_type': 'date',
        'label': '実行時間',
        'name': 'durtime',
        'required': False,
        'type': 'DateTime'},
    {   'default': None,
        'html_type': 'textarea',
        'label': 'コメント',
        'name': 'comment',
        'required': True,
        'type': 'Text'},
    {   'default': None,
        'html_type': 'number',
        'label': '作業者ID',
        'name': 'working_user_id',
        'required': True,
        'type': 'Integer'},
    {   'default': None,
        'html_type': 'number',
        'label': '削除フラグ',
        'name': 'delflg',
        'required': True,
        'type': 'Integer'}]
