
from sqlalchemy import Column, Integer, String
from app.core.base_model import BaseModel

class TWork(BaseModel):
    __tablename__ = "t_work"
    
    customer_id = Column(Integer)
    slip_number = Column(String(50))
    title = Column(String(200))
    facilitator_id = Column(String(50))
    version_id = Column(Integer)
    os_id = Column(Integer)
    folder_id = Column(Integer)
    delflg = Column(Integer, nullable=True, default=0)
    mountflg = Column(Integer, nullable=True, default=0)
    mountflgstr = Column(String(10), nullable=True)

    __fields__ = [   {   'default': None,
        'html_type': 'number',
        'label': '顧客ID',
        'name': 'customer_id',
        'required': True,
        'type': 'Integer'},
    {   'default': None,
        'html_type': 'text',
        'label': '伝票番号',
        'name': 'slip_number',
        'required': True,
        'type': 'String(50)'},
    {   'default': None,
        'html_type': 'text',
        'label': 'タイトル',
        'name': 'title',
        'required': True,
        'type': 'String(200)'},
    {   'default': None,
        'html_type': 'text',
        'label': '進行者ID',
        'name': 'facilitator_id',
        'required': True,
        'type': 'String(50)'},
    {   'default': None,
        'html_type': 'number',
        'label': 'バージョンID',
        'name': 'version_id',
        'required': True,
        'type': 'Integer'},
    {   'default': None,
        'html_type': 'number',
        'label': 'OS ID',
        'name': 'os_id',
        'required': True,
        'type': 'Integer'},
    {   'default': None,
        'html_type': 'number',
        'label': 'フォルダID',
        'name': 'folder_id',
        'required': True,
        'type': 'Integer'},
    {   'default': 0,
        'html_type': 'number',
        'label': '削除フラグ',
        'name': 'delflg',
        'required': False,
        'type': 'Integer'},
    {   'default': 0,
        'html_type': 'number',
        'label': 'マウントフラグ',
        'name': 'mountflg',
        'required': False,
        'type': 'Integer'},
    {   'default': None,
        'html_type': 'text',
        'label': 'マウントフラグ文字列',
        'name': 'mountflgstr',
        'required': False,
        'type': 'String(10)'}]
