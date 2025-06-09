
from sqlalchemy import Column, DateTime, Integer, String
from app.core.base_model import BaseModel

import yaml
import os

# 获取当前模块路径
current_dir = os.getcwd()
config_path = os.path.join(current_dir, 'app', 'config', 'models', 'v_work_summary.yaml')

with open(config_path, 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

class VWorkSummary(BaseModel):
    __tablename__ = "v_work_summary"
    __is_view__ = True

    work_id = Column(Integer, primary_key=True)
    customer_name = Column(String(100))
    slip_number = Column(String(50))
    title = Column(String(200))
    facilitator_name = Column(String(50))
    work_count = Column(Integer)
    last_updated = Column(DateTime)

    # @classmethod
    # async def save_via_view(cls, form_data, db):
    #     #このビューの保存は実際のテーブルに書き込みます
    #     raise NotImplementedError("save_via_view is not implemented")

    @classmethod
    async def save_via_view(cls, form_data, db):
        work_id = form_data.get("work_id")
        if not work_id:
            raise ValueError("work_id は必須です")

        work = db.query(TWork).filter(TWork.id == work_id).first()
        if not work:
            raise ValueError(f"作業ID {work_id} が見つかりません")

        work.title = form_data.get("work_title")
        db.commit()