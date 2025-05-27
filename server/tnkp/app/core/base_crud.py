from fastapi import APIRouter, Depends, HTTPException, Request, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.orm import Session
from fastapi.templating import Jinja2Templates
from typing import Type
from sqlalchemy import or_
from app.models import get_db
from app.core.auth import get_current_user

templates = Jinja2Templates(directory="app/templates")

class BaseCRUD:
    @classmethod
    def create_router(cls, model: Type):
        router = APIRouter(prefix=f"/{model.__tablename__}", tags=[model.__tablename__])
        template_base = model.__tablename__
        
        @router.get("/", response_class=HTMLResponse)
        async def read_items(
            request: Request,
            db: Session = Depends(get_db),
            current_user=Depends(get_current_user),
            page: int = 1,
            per_page: int = 10,
            q: str = None
        ):
            query = db.query(model)
            if q:
                filters = [
                    col.ilike(f"%{q}%")
                    for col in model.__table__.columns
                    if hasattr(col.type, "python_type") and col.type.python_type == str
                ]
                if filters:
                    query = query.filter(or_(*filters))
            total = query.count()
            items = query.offset((page - 1) * per_page).limit(per_page).all()
            fields = [col for col in model.__table__.columns if col.name != 'id']
            return templates.TemplateResponse(
                f"{template_base}/list.html",
                {
                    "request": request,
                    "items": items,
                    "fields": fields,
                    "table_name": model.__tablename__,
                    "model_name": model.__name__,
                    "page": page,
                    "per_page": per_page,
                    "total": total,
                    "q": q or ""
                }
            )

        def column_to_dict(col):
            """将 SQLAlchemy Column 转换为包含元信息的字典"""
            col_type = str(col.type)
            html_type = "text"
            
            if "Integer" in col_type:
                html_type = "number"
            elif "Date" in col_type:
                html_type = "date"
            elif "DateTime" in col_type:
                html_type = "datetime-local"
            elif "Text" in col_type or col.type.python_type == str and col.type.length and col.type.length > 200:
                html_type = "textarea"

            return {
                "name": col.name,
                "type": col.type,
                "nullable": col.nullable,
                "required": not col.nullable,
                "label": col.name.replace("_", " ").title(),
                "html_type": html_type
            }

        @router.get("/new", response_class=HTMLResponse)
        async def create_form(request: Request):
            # fields = [column_to_dict(col) for col in model.__table__.columns if col.name != 'id']
            fields = getattr(model, '__fields__', [])
            return templates.TemplateResponse(
                f"{template_base}/form.html",
                {
                    "request": request, 
                    "item": None,
                    "fields": fields,
                    "table_name": model.__tablename__,
                    "model_name": model.__name__
                }
            )

        @router.get("/{item_id}/edit", response_class=HTMLResponse)
        async def edit_form(request: Request, item_id: int, db: Session = Depends(get_db)):
            item = db.query(model).filter(model.id == item_id).first()
            if not item:
                raise HTTPException(status_code=404, detail="Item not found")
            # fields = [column_to_dict(col) for col in model.__table__.columns if col.name != 'id']
            fields = getattr(model, '__fields__', [])
            return templates.TemplateResponse(
                f"{template_base}/form.html",
                {
                    "request": request,
                    "item": item,
                    "fields": fields,
                    "table_name": model.__tablename__,
                    "model_name": model.__name__
                }
            )
        
        @router.post("/", response_class=HTMLResponse)
        async def create_item(request: Request, db: Session = Depends(get_db)):
            try:
                form_data = await request.form()
                # 过滤掉空值和ID字段
                item_data = {k: v for k, v in form_data.items() if v and k != 'id'}
                item = model(**item_data)
                db.add(item)
                db.commit()
                db.refresh(item)
                return RedirectResponse(url=f"/{model.__tablename__}", status_code=303)
            except Exception as e:
                raise HTTPException(status_code=400, detail=str(e))
        
        @router.get("/{item_id}", response_class=HTMLResponse)
        async def read_item(request: Request, item_id: int, db: Session = Depends(get_db)):
            item = db.query(model).filter(model.id == item_id).first()
            if not item:
                raise HTTPException(status_code=404, detail="Item not found")
            
            fields = [col for col in model.__table__.columns if col.name != 'id']
            return templates.TemplateResponse(
                f"{template_base}/detail.html",
                {
                    "request": request,
                    "item": item,
                    "table_name": model.__tablename__,
                    "model_name": model.__name__,
                    "fields": fields
                }
            )
        
        @router.post("/{item_id}", response_class=HTMLResponse)
        async def update_item(request: Request, item_id: int, db: Session = Depends(get_db)):
            try:
                item = db.query(model).filter(model.id == item_id).first()
                if not item:
                    raise HTTPException(status_code=404, detail="Item not found")
                
                form_data = await request.form()
                for key, value in form_data.items():
                    if hasattr(item, key) and key != 'id':
                        setattr(item, key, value)
                
                db.commit()
                return RedirectResponse(url=f"/{model.__tablename__}", status_code=303)
            except Exception as e:
                raise HTTPException(status_code=400, detail=str(e))
        
        @router.delete("/{item_id}")
        async def delete_item(item_id: int, db: Session = Depends(get_db)):
            item = db.query(model).filter(model.id == item_id).first()
            if not item:
                raise HTTPException(status_code=404, detail="Item not found")
            
            db.delete(item)
            db.commit()
            return {"message": "Item deleted successfully"}

        return router
