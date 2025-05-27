from fastapi import Request, HTTPException, Depends
from app.models import get_db
from app.models.m_users import MUsers
from sqlalchemy.orm import Session

def get_current_user(request: Request, db: Session = Depends(get_db)) -> MUsers:
    user_id = request.session.get("user_id")
    if not user_id:
        raise HTTPException(status_code=401, detail="ログインが必要です")
    user = db.query(MUsers).filter(MUsers.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="ユーザーが存在しません")
    return user
