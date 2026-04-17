from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from ..auth import hash_password
from ..db import get_session
from ..deps import require, get_current_user
from ..models import Role, User
from ..schemas import UserCreate, UserUpdate

router = APIRouter()


def _serialize(user: User, roles_by_id: dict[int, Role]) -> dict:
    role = roles_by_id.get(user.role_id)
    return {
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "role_id": user.role_id,
        "role": role.name if role else None,
        "disabled": user.disabled,
        "created_at": user.created_at.isoformat(),
        "last_login": user.last_login.isoformat() if user.last_login else None,
    }


@router.get("")
def list_users(_: User = Depends(require("users:read")), db: Session = Depends(get_session)):
    users = db.exec(select(User).order_by(User.username)).all()
    roles = {r.id: r for r in db.exec(select(Role)).all()}
    return [_serialize(u, roles) for u in users]


@router.post("")
def create_user(
    payload: UserCreate,
    _: User = Depends(require("users:manage")),
    db: Session = Depends(get_session),
):
    if db.exec(select(User).where(User.username == payload.username)).first():
        raise HTTPException(400, "Username taken")
    if not db.get(Role, payload.role_id):
        raise HTTPException(400, "Role not found")
    user = User(
        username=payload.username.strip(),
        email=(payload.email or "").strip() or None,
        password_hash=hash_password(payload.password),
        role_id=payload.role_id,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    roles = {r.id: r for r in db.exec(select(Role)).all()}
    return _serialize(user, roles)


@router.patch("/{user_id}")
def update_user(
    user_id: int,
    payload: UserUpdate,
    current: User = Depends(require("users:manage")),
    db: Session = Depends(get_session),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    if payload.role_id is not None:
        if not db.get(Role, payload.role_id):
            raise HTTPException(400, "Role not found")
        user.role_id = payload.role_id
    if payload.email is not None:
        user.email = payload.email.strip() or None
    if payload.password is not None:
        user.password_hash = hash_password(payload.password)
    if payload.disabled is not None:
        if user.id == current.id and payload.disabled:
            raise HTTPException(400, "You cannot disable your own account")
        user.disabled = payload.disabled
    db.add(user)
    db.commit()
    db.refresh(user)
    roles = {r.id: r for r in db.exec(select(Role)).all()}
    return _serialize(user, roles)


@router.delete("/{user_id}")
def delete_user(
    user_id: int,
    current: User = Depends(require("users:manage")),
    db: Session = Depends(get_session),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    if user.id == current.id:
        raise HTTPException(400, "You cannot delete your own account")
    # don't allow deleting the last admin
    admin_role = db.exec(select(Role).where(Role.name == "admin")).first()
    if admin_role and user.role_id == admin_role.id:
        remaining = db.exec(
            select(User).where(User.role_id == admin_role.id, User.id != user.id, User.disabled == False)  # noqa: E712
        ).all()
        if not remaining:
            raise HTTPException(400, "Cannot delete the last active admin")
    db.delete(user)
    db.commit()
    return {"ok": True}
