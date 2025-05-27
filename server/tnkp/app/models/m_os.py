
from sqlalchemy import Column, Integer, String
from app.core.base_model import BaseModel

class MOs(BaseModel):
    __tablename__ = "m_os"
    
    name = Column(String(50))
    comment = Column(String(200))
    delflg = Column(Integer, nullable=True, default=0)

    __fields__ = [   {   'default': None,
        'html_type': 'text',
        'label': 'OS名',
        'name': 'name',
        'required': True,
        'type': 'String(50)'},
    {   'default': None,
        'html_type': 'text',
        'label': 'コメント',
        'name': 'comment',
        'required': True,
        'type': 'String(200)'},
    {   'choices': [   {'label': '未完了', 'value': 0},
                       {'label': '進行中', 'value': 1},
                       {'label': '完了', 'value': 2}],
        'default': 0,
        'html_type': 'radio',
        'label': '削除フラグ',
        'name': 'delflg',
        'required': False,
        'type': 'Integer',
        'widget_type': 'radio'}]
