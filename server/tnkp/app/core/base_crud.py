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
        # 处理前缀，确保格式正确
        prefix = f"/{model.__categoryname__.strip('/')}/{model.__tablename__}".replace("//", "/") if model.__categoryname__ else f"/{model.__tablename__}"
        router = APIRouter(prefix=prefix, tags=[model.__tablename__])

        url = f"/{model.__tablename__}"
        if model.__categoryname__:
            url = f"/{model.__categoryname__}/{model.__tablename__}"

        template_base = model.__tablename__
        pk_name = model.get_primary_key()

        def build_breadcrumbs(model, current_label, icon, tail=False):
            breadcrumbs = []

            breadcrumbs.append({"title": "Home", "href": "/", "icon": "fas fa-home"})

            if model.__categoryname__:
                breadcrumbs.append({"title": model.__categoryname__, "href": f"/{model.__categoryname__}", "icon": "fas fa-layer-group"})

                if model.__tablename__:
                    breadcrumbs.append({"title": model.__tablename__, "href": f"/{model.__categoryname__}/{model.__tablename__}", "icon": "fas fa-table"})
            
            elif model.__tablename__:
                breadcrumbs.append({"title": model.__tablename__, "href": f"/{model.__tablename__}", "icon": "fas fa-table"})
            
            breadcrumbs.append({"title": current_label, "icon": icon} if tail else None)

            return breadcrumbs

        from app.utils.yaml_loader import get_model_config
        def get_fields(model):
            config = get_model_config(model.__tablename__)
            return list(config['fields'].values())

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

            from app.utils.yaml_loader import get_list_fields
            fields = get_list_fields(model.__tablename__)

            return templates.TemplateResponse(
                f"{template_base}/list.html",
                {
                    "request": request,
                    "items": items,
                    "fields": fields,
                    "model": model,
                    "table_name": model.__tablename__,
                    "model_name": model.__name__,
                    "page": page,
                    "per_page": per_page,
                    "total": total,
                    "q": q or "",
                    "pk_name": pk_name,
                    "breadcrumbs": build_breadcrumbs(model, "一覧", "fas fa-list", True)
                }
            )

        @router.get("/new", response_class=HTMLResponse)
        async def create_form(request: Request):
            fields = get_fields(model)

            return templates.TemplateResponse(
                f"{template_base}/form.html",
                {
                    "request": request, 
                    "item": None,
                    "fields": fields,
                    "model": model,
                    "table_name": model.__tablename__,
                    "model_name": model.__name__,
                    "pk_name": pk_name,
                    "breadcrumbs": build_breadcrumbs(model, "新規作成", "fas fa-plus", True)
                }
            )

        @router.get("/{item_id}/edit", response_class=HTMLResponse)
        async def edit_form(request: Request, item_id: str, db: Session = Depends(get_db)):
            item = db.query(model).filter(getattr(model, pk_name) == item_id).first()
            if not item:
                raise HTTPException(status_code=404, detail="Item not found")
            fields = get_fields(model)

            return templates.TemplateResponse(
                f"{template_base}/form.html",
                {
                    "request": request,
                    "item": item,
                    "fields": fields,
                    "model": model,
                    "table_name": model.__tablename__,
                    "model_name": model.__name__,
                    "pk_name": pk_name,
                    "breadcrumbs": build_breadcrumbs(model, "編集", "fas fa-edit", True)
                }
            )

        @router.post("/", response_class=HTMLResponse)
        async def create_item(request: Request, db: Session = Depends(get_db)):
            try:
                form_data = await request.form()

                if hasattr(model, "save_via_view"):
                    await model.save_via_view(form_data, db)
                    return RedirectResponse(url=url, status_code=303)

                item_data = {k: v for k, v in form_data.items() if v and k != pk_name}
                item = model(**item_data)
                db.add(item)
                db.commit()
                db.refresh(item)
                return RedirectResponse(url=url, status_code=303)
            except Exception as e:
                raise HTTPException(status_code=400, detail=str(e))

        @router.get("/{item_id}", response_class=HTMLResponse)
        async def read_item(request: Request, item_id: str, db: Session = Depends(get_db)):
            item = db.query(model).filter(getattr(model, pk_name) == item_id).first()
            
            if not item:
                raise HTTPException(status_code=404, detail="Item not found")
            
            fields = get_fields(model)
            for f in fields:
                f["readonly"] = "readonly"
            
            return templates.TemplateResponse(
                f"{template_base}/detail.html",
                {
                    "request": request,
                    "item": item,
                    "fields": fields,
                    "model": model,
                    "table_name": model.__tablename__,
                    "model_name": model.__name__,
                    "pk_name": pk_name,
                    "breadcrumbs": build_breadcrumbs(model, "詳細", "fas fa-eye", True)
                }
            )

        @router.post("/{item_id}", response_class=HTMLResponse)
        async def update_item(request: Request, item_id: str, db: Session = Depends(get_db)):
            try:
                item = db.query(model).filter(getattr(model, pk_name) == item_id).first()
                if not item:
                    raise HTTPException(status_code=404, detail="Item not found")

                form_data = await request.form()

                if hasattr(model, "save_via_view"):
                    await model.save_via_view(form_data, db)
                    return RedirectResponse(url=url, status_code=303)

                for key, value in form_data.items():
                    if hasattr(item, key) and key != pk_name:
                        setattr(item, key, value)
                db.commit()

                return RedirectResponse(url=url, status_code=303)
            except Exception as e:
                raise HTTPException(status_code=400, detail=str(e))

        @router.delete("/{item_id}")
        async def delete_item(item_id: str, db: Session = Depends(get_db)):
            item = db.query(model).filter(getattr(model, pk_name) == item_id).first()
            if not item:
                raise HTTPException(status_code=404, detail="Item not found")
            db.delete(item)
            db.commit()
            return {"message": "Item deleted successfully"}

        return router

