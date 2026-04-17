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


class ConsoleConnection(SQLModel, table=True):
    """A configured UOS console Raptorr can reach on the LAN or via VPN.

    Each connection is a self-contained record — Raptorr doesn't depend on the
    cloud Site Manager API to discover consoles. The user creates one entry
    per console and Raptorr talks to its local Network Integration API.
    """

    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(index=True)
    base_url: str
    api_key: str
    verify_tls: bool = False
    last_test_at: Optional[datetime] = None
    last_test_ok: Optional[bool] = None
    last_test_message: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


ALL_PERMISSIONS = [
    "devices:read",
    "consoles:manage",
    "users:read",
    "users:manage",
    "roles:read",
    "roles:manage",
]

BUILTIN_ROLES = {
    "admin": {
        "description": "Full access to everything.",
        "permissions": ALL_PERMISSIONS,
    },
    "operator": {
        "description": "Search devices, view consoles, view users and roles.",
        "permissions": ["devices:read", "users:read", "roles:read"],
    },
    "viewer": {
        "description": "Search devices only.",
        "permissions": ["devices:read"],
    },
}
