
from sqlalchemy import Column, Integer, String
from app.core.base_model import BaseModel

class MCustomers(BaseModel):
    __tablename__ = "m_customers"
    
    code = Column(String(20))
    name = Column(String(100))
    delflg = Column(Integer)

    __fields__ = [   {   'default': None,
        'html_type': 'text',
        'label': '顧客コード',
        'name': 'code',
        'required': True,
        'type': 'String(20)'},
    {   'default': None,
        'html_type': 'text',
        'label': '顧客名',
        'name': 'name',
        'required': True,
        'type': 'String(100)'},
    {   'choices': [   {'label': '低', 'value': 1},
                       {'label': '中', 'value': 2},
                       {'label': '高', 'value': 3}],
        'default': None,
        'html_type': 'select',
        'label': '削除フラグ',
        'name': 'delflg',
        'required': True,
        'type': 'Integer',
        'widget_type': 'select'}]
