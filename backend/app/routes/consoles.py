from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from ..crypto import decrypt, encrypt
from ..db import get_session
from ..deps import require
from ..local_unifi import (
    IntegrationError,
    LocalUniFiClient,
    mask_key,
    suggest_base_urls,
)
from ..models import ConsoleIntegration, User
from ..schemas import IntegrationTest, IntegrationUpsert

router = APIRouter()


def _serialize(row: ConsoleIntegration) -> dict:
    return {
        "host_id": row.host_id,
        "base_url": row.base_url,
        "api_key_masked": mask_key(decrypt(row.api_key)),
        "verify_tls": row.verify_tls,
        "last_test_at": row.last_test_at.isoformat() if row.last_test_at else None,
        "last_test_ok": row.last_test_ok,
        "last_test_message": row.last_test_message,
        "updated_at": row.updated_at.isoformat(),
    }


@router.get("/integrations")
def list_integrations(
    _: User = Depends(require("settings:read")),
    db: Session = Depends(get_session),
):
    rows = db.exec(select(ConsoleIntegration)).all()
    return [_serialize(r) for r in rows]


@router.get("/integrations/{host_id}")
def get_integration(
    host_id: str,
    _: User = Depends(require("settings:read")),
    db: Session = Depends(get_session),
):
    row = db.get(ConsoleIntegration, host_id)
    if not row:
        raise HTTPException(404, "No integration configured for this host")
    return _serialize(row)


@router.get("/integrations/{host_id}/suggestions")
def get_suggestions(
    host_id: str,
    host_ip: str | None = None,
    _: User = Depends(require("settings:manage")),
):
    return suggest_base_urls(host_id, host_ip)


@router.put("/integrations/{host_id}")
def upsert_integration(
    host_id: str,
    payload: IntegrationUpsert,
    _: User = Depends(require("settings:manage")),
    db: Session = Depends(get_session),
):
    existing = db.get(ConsoleIntegration, host_id)
    now = datetime.utcnow()
    if existing:
        existing.base_url = payload.base_url.strip()
        if payload.api_key:
            existing.api_key = encrypt(payload.api_key.strip())
        existing.verify_tls = payload.verify_tls
        existing.updated_at = now
        db.add(existing)
        db.commit()
        db.refresh(existing)
        return _serialize(existing)
    if not payload.api_key:
        raise HTTPException(400, "api_key required when creating an integration")
    row = ConsoleIntegration(
        host_id=host_id,
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


@router.delete("/integrations/{host_id}")
def delete_integration(
    host_id: str,
    _: User = Depends(require("settings:manage")),
    db: Session = Depends(get_session),
):
    row = db.get(ConsoleIntegration, host_id)
    if row:
        db.delete(row)
        db.commit()
    return {"ok": True}


@router.post("/integrations/{host_id}/test")
async def test_integration(
    host_id: str,
    payload: IntegrationTest,
    _: User = Depends(require("settings:manage")),
    db: Session = Depends(get_session),
):
    saved = db.get(ConsoleIntegration, host_id)

    base_url = (payload.base_url or (saved.base_url if saved else "")).strip()
    api_key = (
        payload.api_key
        if payload.api_key
        else (decrypt(saved.api_key) if saved else "")
    ).strip()
    if payload.verify_tls is None:
        verify_tls = saved.verify_tls if saved else False
    else:
        verify_tls = payload.verify_tls

    if not base_url or not api_key:
        raise HTTPException(400, "base_url and api_key are required")

    client = LocalUniFiClient(base_url, api_key, verify_tls)
    try:
        result = await client.test()
        if saved:
            saved.last_test_at = datetime.utcnow()
            saved.last_test_ok = True
            saved.last_test_message = (
                f"OK — {result['site_count']} site(s); first: {result.get('first_site_name') or 'n/a'}"
            )
            db.add(saved)
            db.commit()
        return {"ok": True, **result}
    except IntegrationError as exc:
        if saved:
            saved.last_test_at = datetime.utcnow()
            saved.last_test_ok = False
            saved.last_test_message = str(exc)
            db.add(saved)
            db.commit()
        return {"ok": False, "error": str(exc), "status": exc.status}


def _client_for(db: Session, host_id: str) -> LocalUniFiClient:
    integration = db.get(ConsoleIntegration, host_id)
    if not integration:
        raise HTTPException(404, "No local integration configured for this host")
    return LocalUniFiClient(
        integration.base_url,
        decrypt(integration.api_key),
        integration.verify_tls,
    )


@router.get("/{host_id}/sites")
async def get_local_sites(
    host_id: str,
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    client = _client_for(db, host_id)
    try:
        return await client.list_sites()
    except IntegrationError as exc:
        raise HTTPException(502, str(exc))


@router.get("/{host_id}/sites/{site_id}/devices")
async def get_local_site_devices(
    host_id: str,
    site_id: str,
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    client = _client_for(db, host_id)
    try:
        return await client.list_devices(site_id)
    except IntegrationError as exc:
        raise HTTPException(502, str(exc))


@router.get("/{host_id}/sites/{site_id}/clients")
async def get_local_site_clients(
    host_id: str,
    site_id: str,
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    client = _client_for(db, host_id)
    try:
        return await client.list_clients(site_id)
    except IntegrationError as exc:
        raise HTTPException(502, str(exc))
