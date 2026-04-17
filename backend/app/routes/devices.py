from fastapi import APIRouter, Depends, Query
from sqlmodel import Session

from ..db import get_session
from ..deps import require
from ..models import User
from ..unifi import UniFiClient, cache, get_api_key

router = APIRouter()


def _flatten_devices(hosts: list[dict], devices_payload: list[dict]) -> list[dict]:
    host_by_id: dict[str, dict] = {}
    for h in hosts:
        hid = h.get("id") or h.get("hostId")
        if hid:
            host_by_id[hid] = h

    flat: list[dict] = []
    for entry in devices_payload:
        host_id = entry.get("hostId")
        host = host_by_id.get(host_id, {})
        host_meta = host.get("reportedState", {}) if isinstance(host, dict) else {}
        host_name = host_meta.get("hostname") or host_meta.get("name") or host.get("hostname")
        for d in entry.get("devices", []):
            flat.append(
                {
                    "id": d.get("id"),
                    "name": d.get("name"),
                    "model": d.get("model") or d.get("shortname"),
                    "mac": d.get("mac"),
                    "ip": d.get("ip"),
                    "firmware": d.get("firmwareVersion") or d.get("firmware"),
                    "status": d.get("status") or d.get("state"),
                    "adopted": d.get("adopted"),
                    "uptime_sec": d.get("uptime") or d.get("uptimeSec"),
                    "site": d.get("siteName") or d.get("site"),
                    "host_id": host_id,
                    "host_name": host_name,
                    "raw": d,
                }
            )
    return flat


def _matches(device: dict, needle: str) -> bool:
    if not needle:
        return True
    haystack = " ".join(
        str(device.get(k) or "") for k in (
            "name", "mac", "ip", "model", "site", "host_name", "status", "firmware"
        )
    ).lower()
    return needle in haystack


@router.get("/search")
async def search_devices(
    q: str | None = Query(default=None),
    limit: int = Query(default=500, ge=1, le=2000),
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    api_key = get_api_key(db)
    client = UniFiClient(api_key)

    hosts = await cache.get_or_set("hosts", client.list_hosts)
    host_ids = [h.get("id") or h.get("hostId") for h in hosts]
    host_ids = [h for h in host_ids if h]
    devices_payload = await cache.get_or_set(
        "devices", lambda: client.list_devices(host_ids=host_ids)
    )

    devices = _flatten_devices(hosts, devices_payload)
    needle = (q or "").strip().lower()
    if needle:
        devices = [d for d in devices if _matches(d, needle)]

    return {
        "total_hosts": len(hosts),
        "total_devices": len(devices),
        "devices": devices[:limit],
    }


@router.post("/refresh")
async def refresh_cache(_: User = Depends(require("devices:read"))):
    cache.invalidate()
    return {"ok": True}


@router.get("/sites")
async def list_sites(
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    api_key = get_api_key(db)
    client = UniFiClient(api_key)
    sites = await cache.get_or_set("sites", client.list_sites)
    return sites
