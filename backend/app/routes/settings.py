from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session

from ..db import get_session
from ..deps import require
from ..models import User
from ..schemas import ApiKeyRequest
from ..unifi import UniFiClient, cache, get_api_key, has_api_key, set_api_key

router = APIRouter()


def _masked(key: str) -> str:
    if not key:
        return ""
    if len(key) <= 8:
        return "*" * len(key)
    return key[:4] + "…" + key[-4:]


@router.get("/api-key")
def read_api_key(
    _: User = Depends(require("settings:read")),
    db: Session = Depends(get_session),
):
    try:
        key = get_api_key(db)
        return {"configured": True, "masked": _masked(key)}
    except HTTPException:
        return {"configured": False, "masked": ""}


@router.put("/api-key")
async def update_api_key(
    payload: ApiKeyRequest,
    _: User = Depends(require("settings:manage")),
    db: Session = Depends(get_session),
):
    key = payload.api_key.strip()
    if not key:
        raise HTTPException(400, "API key required")
    # probe the API to validate
    client = UniFiClient(key)
    await client.test()
    set_api_key(db, key)
    cache.invalidate()
    return {"configured": True, "masked": _masked(key)}
