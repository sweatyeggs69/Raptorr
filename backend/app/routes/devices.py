"""Cross-console aggregated device + client search.

Fans out to every configured ConsoleConnection's local Network Integration
API, pulling sites and then devices per site. Results are flattened and
lightly normalised so the UI can sort/filter uniformly, with cache-friendly
fan-out so the UI stays responsive on repeat loads.
"""

import asyncio
from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlmodel import Session, select

from ..cache import TTLCache
from ..config import settings
from ..crypto import decrypt
from ..db import get_session
from ..deps import require
from ..local_unifi import IntegrationError, LocalUniFiClient
from ..models import ConsoleConnection, User

router = APIRouter()

cache = TTLCache(settings.cache_ttl_seconds)


def _site_label(site: dict) -> str | None:
    return (
        site.get("name")
        or site.get("internalReference")
        or site.get("id")
    )


def _device_status(device: dict) -> tuple[bool | None, str]:
    state = device.get("state") or device.get("status") or ""
    if isinstance(state, str):
        s = state.lower()
    else:
        s = str(state).lower()
    if not s:
        return None, "unknown"
    if any(t in s for t in ("online", "connected", "adopted")):
        return True, state if isinstance(state, str) else s
    if any(t in s for t in ("offline", "disconnected", "unreachable", "pending")):
        return False, state if isinstance(state, str) else s
    return None, state if isinstance(state, str) else s


def _device_type(device: dict) -> str:
    pl = device.get("productLine") or device.get("type") or ""
    if isinstance(pl, str) and pl.strip():
        pl = pl.strip().lower()
        mapping = {
            "network": "Network",
            "protect": "Protect",
            "access": "Access",
            "talk": "Talk",
            "connect": "Connect",
            "drive": "Drive",
        }
        return mapping.get(pl, pl[:1].upper() + pl[1:])
    return "Network"


def _flatten_device(
    device: dict,
    *,
    console_id: int,
    console_name: str,
    site_id: str,
    site_name: str | None,
) -> dict:
    online, status_label = _device_status(device)
    return {
        "id": device.get("id"),
        "name": device.get("name") or device.get("hostname"),
        "model": device.get("model"),
        "mac": device.get("macAddress") or device.get("mac"),
        "ip": device.get("ipAddress") or device.get("ip"),
        "firmware": device.get("firmwareVersion") or device.get("version"),
        "status": status_label,
        "is_online": online,
        "device_type": _device_type(device),
        "uptime_sec": device.get("uptime") or device.get("uptimeSec"),
        "site_id": site_id,
        "site_name": site_name,
        "console_id": console_id,
        "console_name": console_name,
        "raw": device,
    }


def _matches(device: dict, needle: str) -> bool:
    if not needle:
        return True
    haystack = " ".join(
        str(device.get(k) or "")
        for k in (
            "name",
            "mac",
            "ip",
            "model",
            "site_name",
            "console_name",
            "status",
            "firmware",
            "device_type",
        )
    ).lower()
    return needle in haystack


async def _load_console_inventory(row: ConsoleConnection) -> dict:
    """Load all sites + devices for a single console. Cached per-console."""

    cache_key = f"inv:{row.id}:{row.updated_at.isoformat()}"

    async def factory():
        client = LocalUniFiClient(row.base_url, decrypt(row.api_key), row.verify_tls)
        sites = await client.list_sites()
        # Fan out per-site device fetches; bound concurrency to avoid hammering.
        sem = asyncio.Semaphore(6)

        async def one_site(site: dict):
            sid = site.get("id")
            if not sid:
                return sid, _site_label(site), []
            async with sem:
                try:
                    devices = await client.list_devices(sid)
                except IntegrationError as exc:
                    raise exc
            return sid, _site_label(site), devices

        results = await asyncio.gather(
            *[one_site(s) for s in sites], return_exceptions=True
        )
        per_site: list[dict] = []
        for item in results:
            if isinstance(item, Exception):
                continue
            sid, sname, devices = item
            per_site.append(
                {
                    "site_id": sid,
                    "site_name": sname,
                    "devices": devices,
                }
            )
        return {"sites": per_site}

    return await cache.get_or_set(cache_key, factory)


@router.get("/search")
async def search_devices(
    q: str | None = Query(default=None),
    console_id: int | None = Query(default=None),
    site_id: str | None = Query(default=None),
    limit: int = Query(default=1000, ge=1, le=5000),
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    rows = db.exec(select(ConsoleConnection).order_by(ConsoleConnection.name)).all()
    if console_id is not None:
        rows = [r for r in rows if r.id == console_id]

    # Fetch each console's inventory in parallel.
    async def one_console(row: ConsoleConnection):
        try:
            inv = await _load_console_inventory(row)
            return {"row": row, "inventory": inv, "error": None}
        except IntegrationError as exc:
            return {"row": row, "inventory": None, "error": str(exc)}

    fanout = await asyncio.gather(
        *[one_console(r) for r in rows], return_exceptions=False
    )

    flat: list[dict] = []
    errors: list[dict[str, Any]] = []
    total_sites = 0
    total_consoles_ok = 0

    for result in fanout:
        row: ConsoleConnection = result["row"]
        if result["error"]:
            errors.append({"console_id": row.id, "console_name": row.name, "error": result["error"]})
            continue
        total_consoles_ok += 1
        for site in result["inventory"]["sites"]:
            total_sites += 1
            sid = site["site_id"]
            if site_id and sid != site_id:
                continue
            for d in site["devices"]:
                flat.append(
                    _flatten_device(
                        d,
                        console_id=row.id,
                        console_name=row.name,
                        site_id=sid,
                        site_name=site["site_name"],
                    )
                )

    needle = (q or "").strip().lower()
    if needle:
        flat = [d for d in flat if _matches(d, needle)]

    return {
        "devices": flat[:limit],
        "total_devices": len(flat),
        "total_sites": total_sites,
        "total_consoles": len(rows),
        "total_consoles_ok": total_consoles_ok,
        "errors": errors,
        "cache": {
            "ttl_seconds": settings.cache_ttl_seconds,
        },
    }


@router.post("/refresh")
async def refresh(_: User = Depends(require("devices:read"))):
    cache.invalidate()
    return {"ok": True}
