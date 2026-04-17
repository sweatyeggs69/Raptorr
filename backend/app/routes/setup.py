from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from ..auth import hash_password
from ..db import get_session
from ..models import BUILTIN_ROLES, Role, RolePermission, User
from ..schemas import SetupRequest
from ..unifi import set_api_key

router = APIRouter()


def _setup_complete(db: Session) -> bool:
    return db.exec(select(User).limit(1)).first() is not None


def _ensure_builtin_roles(db: Session) -> Role:
    admin_role: Role | None = None
    for name, spec in BUILTIN_ROLES.items():
        existing = db.exec(select(Role).where(Role.name == name)).first()
        if existing:
            if name == "admin":
                admin_role = existing
            continue
        role = Role(name=name, description=spec["description"], builtin=True)
        db.add(role)
        db.commit()
        db.refresh(role)
        for perm in spec["permissions"]:
            db.add(RolePermission(role_id=role.id, permission=perm))
        db.commit()
        if name == "admin":
            admin_role = role
    if not admin_role:
        admin_role = db.exec(select(Role).where(Role.name == "admin")).first()
    assert admin_role is not None
    return admin_role


@router.get("/status")
def status(db: Session = Depends(get_session)):
    return {"completed": _setup_complete(db)}


@router.post("/complete")
def complete(payload: SetupRequest, db: Session = Depends(get_session)):
    if _setup_complete(db):
        raise HTTPException(400, "Setup already completed")

    admin_role = _ensure_builtin_roles(db)

    user = User(
        username=payload.username.strip(),
        email=(payload.email or "").strip() or None,
        password_hash=hash_password(payload.password),
        role_id=admin_role.id,
    )
    db.add(user)
    db.commit()

    if payload.api_key:
        set_api_key(db, payload.api_key.strip())

    return {"ok": True}
