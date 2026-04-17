from typing import Optional
from pydantic import BaseModel, Field


class SetupRequest(BaseModel):
    username: str = Field(min_length=3, max_length=64)
    email: Optional[str] = None
    password: str = Field(min_length=8, max_length=128)
    api_key: Optional[str] = None


class LoginRequest(BaseModel):
    username: str
    password: str


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=64)
    email: Optional[str] = None
    password: str = Field(min_length=8, max_length=128)
    role_id: int


class UserUpdate(BaseModel):
    email: Optional[str] = None
    password: Optional[str] = Field(default=None, min_length=8, max_length=128)
    role_id: Optional[int] = None
    disabled: Optional[bool] = None


class RoleCreate(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    description: str = ""
    permissions: list[str] = []


class RoleUpdate(BaseModel):
    description: Optional[str] = None
    permissions: Optional[list[str]] = None


class ApiKeyRequest(BaseModel):
    api_key: str


class IntegrationUpsert(BaseModel):
    base_url: str = Field(min_length=1, max_length=512)
    api_key: Optional[str] = Field(default=None, max_length=512)
    verify_tls: bool = False


class IntegrationTest(BaseModel):
    base_url: Optional[str] = Field(default=None, max_length=512)
    api_key: Optional[str] = Field(default=None, max_length=512)
    verify_tls: Optional[bool] = None
