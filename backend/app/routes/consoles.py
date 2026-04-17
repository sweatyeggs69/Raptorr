from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from ..crypto import decrypt, encrypt
from ..db import get_session
from ..deps import require
from ..local_unifi import IntegrationError, LocalUniFiClient, mask_key
from ..models import ConsoleConnection, User
from ..schemas import ConsoleCreate, ConsoleTest, ConsoleUpdate

router = APIRouter()


def _serialize(row: ConsoleConnection) -> dict:
    return {
        "id": row.id,
        "name": row.name,
        "base_url": row.base_url,
        "api_key_masked": mask_key(decrypt(row.api_key)),
        "verify_tls": row.verify_tls,
        "last_test_at": row.last_test_at.isoformat() if row.last_test_at else None,
        "last_test_ok": row.last_test_ok,
        "last_test_message": row.last_test_message,
        "created_at": row.created_at.isoformat(),
        "updated_at": row.updated_at.isoformat(),
    }


def _require_row(db: Session, console_id: int) -> ConsoleConnection:
    row = db.get(ConsoleConnection, console_id)
    if not row:
        raise HTTPException(404, "Console not found")
    return row


def _client_for(row: ConsoleConnection) -> LocalUniFiClient:
    return LocalUniFiClient(row.base_url, decrypt(row.api_key), row.verify_tls)


@router.get("")
def list_consoles(
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    rows = db.exec(select(ConsoleConnection).order_by(ConsoleConnection.name)).all()
    return [_serialize(r) for r in rows]


@router.post("")
def create_console(
    payload: ConsoleCreate,
    _: User = Depends(require("consoles:manage")),
    db: Session = Depends(get_session),
):
    now = datetime.utcnow()
    row = ConsoleConnection(
        name=payload.name.strip(),
        base_url=payload.base_url.strip(),
        api_key=encrypt(payload.api_key.strip()),
        verify_tls=payload.verify_tls,
        created_at=now,
        updated_at=now,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _serialize(row)


@router.get("/{console_id}")
def get_console(
    console_id: int,
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    return _serialize(_require_row(db, console_id))


@router.patch("/{console_id}")
def update_console(
    console_id: int,
    payload: ConsoleUpdate,
    _: User = Depends(require("consoles:manage")),
    db: Session = Depends(get_session),
):
    row = _require_row(db, console_id)
    if payload.name is not None:
        row.name = payload.name.strip()
    if payload.base_url is not None:
        row.base_url = payload.base_url.strip()
    if payload.api_key is not None:
        row.api_key = encrypt(payload.api_key.strip())
    if payload.verify_tls is not None:
        row.verify_tls = payload.verify_tls
    row.updated_at = datetime.utcnow()
    db.add(row)
    db.commit()
    db.refresh(row)
    return _serialize(row)


@router.delete("/{console_id}")
def delete_console(
    console_id: int,
    _: User = Depends(require("consoles:manage")),
    db: Session = Depends(get_session),
):
    row = db.get(ConsoleConnection, console_id)
    if row:
        db.delete(row)
        db.commit()
    return {"ok": True}


async def _do_test(base_url: str, api_key: str, verify_tls: bool) -> dict:
    client = LocalUniFiClient(base_url, api_key, verify_tls)
    try:
        result = await client.test()
        return {"ok": True, **result}
    except IntegrationError as exc:
        return {"ok": False, "error": str(exc), "status": exc.status}


@router.post("/test")
async def test_unsaved(
    payload: ConsoleTest,
    _: User = Depends(require("consoles:manage")),
):
    if not payload.base_url or not payload.api_key:
        raise HTTPException(400, "base_url and api_key are required")
    return await _do_test(
        payload.base_url.strip(),
        payload.api_key.strip(),
        bool(payload.verify_tls),
    )


@router.post("/{console_id}/test")
async def test_console(
    console_id: int,
    payload: ConsoleTest,
    _: User = Depends(require("consoles:manage")),
    db: Session = Depends(get_session),
):
    row = _require_row(db, console_id)
    base_url = (payload.base_url or row.base_url).strip()
    api_key = (payload.api_key.strip() if payload.api_key else decrypt(row.api_key))
    verify_tls = row.verify_tls if payload.verify_tls is None else payload.verify_tls
    if not base_url or not api_key:
        raise HTTPException(400, "base_url and api_key are required")
    result = await _do_test(base_url, api_key, verify_tls)
    row.last_test_at = datetime.utcnow()
    if result["ok"]:
        row.last_test_ok = True
        row.last_test_message = (
            f"OK — {result.get('site_count', 0)} site(s); "
            f"first: {result.get('first_site_name') or 'n/a'}"
        )
    else:
        row.last_test_ok = False
        row.last_test_message = result.get("error", "Unknown error")
    db.add(row)
    db.commit()
    return result


@router.get("/{console_id}/sites")
async def get_sites(
    console_id: int,
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    row = _require_row(db, console_id)
    try:
        return await _client_for(row).list_sites()
    except IntegrationError as exc:
        raise HTTPException(502, str(exc))


@router.get("/{console_id}/sites/{site_id}/devices")
async def get_site_devices(
    console_id: int,
    site_id: str,
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    row = _require_row(db, console_id)
    try:
        return await _client_for(row).list_devices(site_id)
    except IntegrationError as exc:
        raise HTTPException(502, str(exc))


@router.get("/{console_id}/sites/{site_id}/clients")
async def get_site_clients(
    console_id: int,
    site_id: str,
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    row = _require_row(db, console_id)
    try:
        return await _client_for(row).list_clients(site_id)
    except IntegrationError as exc:
        raise HTTPException(502, str(exc))
