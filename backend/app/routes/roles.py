from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from ..db import get_session
from ..deps import require
from ..models import ALL_PERMISSIONS, Role, RolePermission, User
from ..schemas import RoleCreate, RoleUpdate

router = APIRouter()


def _serialize(role: Role, perms: list[str]) -> dict:
    return {
        "id": role.id,
        "name": role.name,
        "description": role.description,
        "builtin": role.builtin,
        "permissions": perms,
    }


def _perms_for(db: Session, role_id: int) -> list[str]:
    rows = db.exec(
        select(RolePermission.permission).where(RolePermission.role_id == role_id)
    ).all()
    return sorted(rows)


@router.get("/permissions")
def list_permissions(_: User = Depends(require("roles:read"))):
    return ALL_PERMISSIONS


@router.get("")
def list_roles(_: User = Depends(require("roles:read")), db: Session = Depends(get_session)):
    roles = db.exec(select(Role).order_by(Role.name)).all()
    return [_serialize(r, _perms_for(db, r.id)) for r in roles]


@router.post("")
def create_role(
    payload: RoleCreate,
    _: User = Depends(require("roles:manage")),
    db: Session = Depends(get_session),
):
    name = payload.name.strip()
    if db.exec(select(Role).where(Role.name == name)).first():
        raise HTTPException(400, "Role name taken")
    invalid = [p for p in payload.permissions if p not in ALL_PERMISSIONS]
    if invalid:
        raise HTTPException(400, f"Invalid permissions: {invalid}")
    role = Role(name=name, description=payload.description, builtin=False)
    db.add(role)
    db.commit()
    db.refresh(role)
    for p in set(payload.permissions):
        db.add(RolePermission(role_id=role.id, permission=p))
    db.commit()
    return _serialize(role, _perms_for(db, role.id))


@router.patch("/{role_id}")
def update_role(
    role_id: int,
    payload: RoleUpdate,
    _: User = Depends(require("roles:manage")),
    db: Session = Depends(get_session),
):
    role = db.get(Role, role_id)
    if not role:
        raise HTTPException(404, "Role not found")
    if payload.description is not None:
        role.description = payload.description
        db.add(role)
    if payload.permissions is not None:
        if role.builtin and role.name == "admin":
            raise HTTPException(400, "Cannot modify admin role permissions")
        invalid = [p for p in payload.permissions if p not in ALL_PERMISSIONS]
        if invalid:
            raise HTTPException(400, f"Invalid permissions: {invalid}")
        existing = db.exec(
            select(RolePermission).where(RolePermission.role_id == role_id)
        ).all()
        for row in existing:
            db.delete(row)
        for p in set(payload.permissions):
            db.add(RolePermission(role_id=role.id, permission=p))
    db.commit()
    db.refresh(role)
    return _serialize(role, _perms_for(db, role.id))


@router.delete("/{role_id}")
def delete_role(
    role_id: int,
    _: User = Depends(require("roles:manage")),
    db: Session = Depends(get_session),
):
    role = db.get(Role, role_id)
    if not role:
        raise HTTPException(404, "Role not found")
    if role.builtin:
        raise HTTPException(400, "Cannot delete built-in role")
    in_use = db.exec(select(User).where(User.role_id == role_id).limit(1)).first()
    if in_use:
        raise HTTPException(400, "Role is assigned to users")
    perms = db.exec(select(RolePermission).where(RolePermission.role_id == role_id)).all()
    for p in perms:
        db.delete(p)
    db.delete(role)
    db.commit()
    return {"ok": True}
