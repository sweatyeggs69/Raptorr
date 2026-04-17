from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlmodel import Session, select

from ..auth import (
    create_session,
    delete_session,
    permissions_for_user,
    role_name_for_user,
    verify_password,
)
from ..config import settings
from ..db import get_session
from ..deps import get_current_user
from ..models import User
from ..schemas import LoginRequest

router = APIRouter()


def _set_cookie(response: Response, sid: str) -> None:
    response.set_cookie(
        key=settings.session_cookie,
        value=sid,
        max_age=settings.session_ttl_hours * 3600,
        httponly=True,
        samesite="lax",
        secure=False,
        path="/",
    )


@router.post("/login")
def login(
    payload: LoginRequest,
    response: Response,
    db: Session = Depends(get_session),
):
    user = db.exec(select(User).where(User.username == payload.username)).first()
    if not user or user.disabled or not verify_password(payload.password, user.password_hash):
        raise HTTPException(401, "Invalid credentials")
    user.last_login = datetime.utcnow()
    db.add(user)
    db.commit()
    session = create_session(db, user.id)
    _set_cookie(response, session.id)
    return {
        "user": {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "role": role_name_for_user(db, user),
        },
        "permissions": sorted(permissions_for_user(db, user)),
    }


@router.post("/logout")
def logout(
    request: Request,
    response: Response,
    db: Session = Depends(get_session),
):
    sid = request.cookies.get(settings.session_cookie)
    if sid:
        delete_session(db, sid)
    response.delete_cookie(settings.session_cookie, path="/")
    return {"ok": True}


@router.get("/me")
def me(user: User = Depends(get_current_user), db: Session = Depends(get_session)):
    return {
        "user": {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "role": role_name_for_user(db, user),
        },
        "permissions": sorted(permissions_for_user(db, user)),
    }
