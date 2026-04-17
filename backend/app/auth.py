import secrets
from datetime import datetime, timedelta
from passlib.context import CryptContext
from sqlmodel import Session, select

from .config import settings
from .models import User, UserSession, Role, RolePermission

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    try:
        return pwd_context.verify(password, hashed)
    except Exception:
        return False


def create_session(db: Session, user_id: int) -> UserSession:
    sid = secrets.token_urlsafe(32)
    session = UserSession(
        id=sid,
        user_id=user_id,
        expires_at=datetime.utcnow() + timedelta(hours=settings.session_ttl_hours),
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


def get_valid_session(db: Session, sid: str) -> UserSession | None:
    session = db.get(UserSession, sid)
    if not session:
        return None
    if session.expires_at <= datetime.utcnow():
        db.delete(session)
        db.commit()
        return None
    return session


def delete_session(db: Session, sid: str) -> None:
    session = db.get(UserSession, sid)
    if session:
        db.delete(session)
        db.commit()


def permissions_for_user(db: Session, user: User) -> set[str]:
    rows = db.exec(
        select(RolePermission.permission).where(RolePermission.role_id == user.role_id)
    ).all()
    return set(rows)


def role_name_for_user(db: Session, user: User) -> str:
    role = db.get(Role, user.role_id)
    return role.name if role else ""
