from fastapi import Depends, HTTPException, Request, status
from sqlmodel import Session

from .auth import get_valid_session, permissions_for_user
from .config import settings
from .db import get_session
from .models import User


def get_current_user(
    request: Request,
    db: Session = Depends(get_session),
) -> User:
    sid = request.cookies.get(settings.session_cookie)
    if not sid:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Not authenticated")
    session = get_valid_session(db, sid)
    if not session:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Session expired")
    user = db.get(User, session.user_id)
    if not user or user.disabled:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Account disabled")
    return user


def require(permission: str):
    def dep(
        user: User = Depends(get_current_user),
        db: Session = Depends(get_session),
    ) -> User:
        perms = permissions_for_user(db, user)
        if permission not in perms:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN, f"Missing permission: {permission}"
            )
        return user

    return dep
