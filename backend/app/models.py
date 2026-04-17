from datetime import datetime
from typing import Optional
from sqlmodel import SQLModel, Field


class Role(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(unique=True, index=True)
    description: str = ""
    builtin: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)


class RolePermission(SQLModel, table=True):
    role_id: int = Field(foreign_key="role.id", primary_key=True)
    permission: str = Field(primary_key=True)


class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(unique=True, index=True)
    email: Optional[str] = None
    password_hash: str
    role_id: int = Field(foreign_key="role.id")
    disabled: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    last_login: Optional[datetime] = None


class UserSession(SQLModel, table=True):
    __tablename__ = "user_session"
    id: str = Field(primary_key=True)
    user_id: int = Field(foreign_key="user.id", index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime


class AppSetting(SQLModel, table=True):
    key: str = Field(primary_key=True)
    value: str = ""


ALL_PERMISSIONS = [
    "devices:read",
    "users:read",
    "users:manage",
    "roles:read",
    "roles:manage",
    "settings:read",
    "settings:manage",
]

BUILTIN_ROLES = {
    "admin": {
        "description": "Full access to everything.",
        "permissions": ALL_PERMISSIONS,
    },
    "operator": {
        "description": "Can search devices and view users and roles.",
        "permissions": ["devices:read", "users:read", "roles:read", "settings:read"],
    },
    "viewer": {
        "description": "Can search devices only.",
        "permissions": ["devices:read"],
    },
}
