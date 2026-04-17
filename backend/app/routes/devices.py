from collections import defaultdict

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlmodel import Session

from ..config import settings
from ..db import get_session
from ..deps import require
from ..models import User
from ..unifi import UniFiClient, cache, get_api_key

router = APIRouter()


CLOUD_CONSOLE_BASE = "https://unifi.ui.com/consoles"


def _host_ip(host_meta: dict) -> str | None:
    for key in ("ip", "mgmtIp", "hostIp"):
        value = host_meta.get(key)
        if isinstance(value, str) and value:
            return value
    ip_addrs = host_meta.get("ipAddrs") or host_meta.get("ip_addresses")
    if isinstance(ip_addrs, list) and ip_addrs:
        first = ip_addrs[0]
        if isinstance(first, str):
            return first
        if isinstance(first, dict):
            for k in ("ip", "addr", "address"):
                if isinstance(first.get(k), str) and first.get(k):
                    return first[k]
    return None


def _console_links(host_id: str | None, host_meta: dict) -> dict[str, str | None]:
    cloud = f"{CLOUD_CONSOLE_BASE}/{host_id}" if host_id else None
    ip = _host_ip(host_meta)
    local = f"https://{ip}" if ip else None
    return {"cloud_url": cloud, "local_url": local, "host_ip": ip}


def _site_id(site: dict) -> str | None:
    return site.get("siteId") or site.get("id") or site.get("site_id")


def _site_name(site: dict) -> str | None:
    # Site Manager has shifted this around; try every reasonable spot.
    meta = site.get("meta") if isinstance(site.get("meta"), dict) else {}
    internal = (
        site.get("internalReference")
        if isinstance(site.get("internalReference"), dict)
        else {}
    )
    reported = (
        site.get("reportedState")
        if isinstance(site.get("reportedState"), dict)
        else {}
    )
    desc = meta.get("desc") or meta.get("description")
    name = (
        meta.get("name")
        or reported.get("name")
        or internal.get("name")
        or site.get("siteName")
        or site.get("name")
        or site.get("displayName")
        or desc
    )
    if name:
        return name
    # Last resort: expose something readable so the UI doesn't show blanks.
    sid = _site_id(site)
    if sid:
        return f"site {sid[-8:]}" if len(sid) > 8 else f"site {sid}"
    return None


def _host_id_of(host: dict) -> str | None:
    return host.get("id") or host.get("hostId")


def _host_meta(host: dict) -> dict:
    return host.get("reportedState") if isinstance(host.get("reportedState"), dict) else {}


def _host_name(host: dict) -> str | None:
    meta = _host_meta(host)
    return meta.get("name") or meta.get("hostname") or host.get("hostname")


def _summarize_host(host: dict) -> dict:
    host_id = _host_id_of(host)
    meta = _host_meta(host)
    links = _console_links(host_id, meta)
    return {
        "id": host_id,
        "name": meta.get("name") or meta.get("hostname") or host.get("hostname"),
        "hardware_id": meta.get("hardwareId") or host.get("hardwareId"),
        "type": meta.get("type") or host.get("type"),
        "version": meta.get("version") or host.get("version"),
        "host_ip": links["host_ip"],
        "console_cloud_url": links["cloud_url"],
        "console_local_url": links["local_url"],
    }


def _summarize_site(site: dict) -> dict:
    return {
        "id": _site_id(site),
        "name": _site_name(site),
        "host_id": site.get("hostId"),
        "statistics": site.get("statistics"),
    }


def _device_site_ref(device: dict) -> tuple[str | None, str | None]:
    site_id = device.get("siteId") or device.get("site_id")
    site_name = device.get("siteName") or device.get("site")
    return site_id, site_name


def _device_type(device: dict) -> str:
    if device.get("isConsole") is True:
        return "Console"
    product_line = device.get("productLine") or device.get("product_line")
    if isinstance(product_line, str) and product_line.strip():
        pl = product_line.strip().lower()
        mapping = {
            "network": "Network",
            "protect": "Protect",
            "access": "Access",
            "talk": "Talk",
            "connect": "Connect",
            "drive": "Drive",
            "amplifi": "AmpliFi",
        }
        return mapping.get(pl, pl[:1].upper() + pl[1:])
    return "Network"


def _is_online(status: str | None, device: dict) -> bool | None:
    state = device.get("state")
    if isinstance(state, (int, float)):
        if state == 0:
            return False
        if state in (1, 2, 3, 4, 5):
            return True
    if not status:
        return None
    s = status.lower()
    if any(t in s for t in ("online", "connected", "active", "running")):
        return True
    if any(t in s for t in ("offline", "disconnected", "unreachable")):
        return False
    return None


def _flatten_device(
    device: dict,
    host: dict,
    host_id: str | None,
    host_name: str | None,
    links: dict,
    site_by_id: dict[str, dict],
) -> dict:
    site_id, site_name = _device_site_ref(device)
    if site_id and not site_name:
        ref = site_by_id.get(site_id)
        if ref:
            site_name = _site_name(ref)
    status = device.get("status") or device.get("state")
    status_text = status if isinstance(status, str) else None
    return {
        "id": device.get("id"),
        "name": device.get("name"),
        "model": device.get("model") or device.get("shortname"),
        "mac": device.get("mac"),
        "ip": device.get("ip"),
        "firmware": device.get("firmwareVersion") or device.get("firmware"),
        "status": status_text if status_text is not None else (str(status) if status is not None else None),
        "is_online": _is_online(status_text, device),
        "device_type": _device_type(device),
        "adopted": device.get("adopted"),
        "uptime_sec": device.get("uptime") or device.get("uptimeSec"),
        "site_id": site_id,
        "site_name": site_name,
        "site": site_name,
        "host_id": host_id,
        "host_name": host_name,
        "console_cloud_url": links["cloud_url"],
        "console_local_url": links["local_url"],
        "host_ip": links["host_ip"],
        "raw": device,
    }


def _flatten_devices(
    hosts: list[dict],
    devices_payload: list[dict],
    sites: list[dict],
) -> list[dict]:
    host_by_id: dict[str, dict] = {
        hid: h for h in hosts if (hid := _host_id_of(h))
    }
    site_by_id: dict[str, dict] = {
        sid: s for s in sites if (sid := _site_id(s))
    }

    flat: list[dict] = []
    for entry in devices_payload:
        host_id = entry.get("hostId")
        host = host_by_id.get(host_id, {})
        links = _console_links(host_id, _host_meta(host))
        host_name = _host_name(host)
        for d in entry.get("devices", []):
            flat.append(
                _flatten_device(d, host, host_id, host_name, links, site_by_id)
            )
    return flat


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
            "host_name",
            "status",
            "firmware",
            "device_type",
        )
    ).lower()
    return needle in haystack


def _cache_info() -> dict:
    return {
        "age_seconds": cache.age("devices"),
        "ttl_seconds": settings.cache_ttl_seconds,
    }


async def _load_all(db: Session):
    api_key = get_api_key(db)
    client = UniFiClient(api_key)
    hosts = await cache.get_or_set("hosts", client.list_hosts)
    sites = await cache.get_or_set("sites", client.list_sites)
    host_ids = [hid for h in hosts if (hid := _host_id_of(h))]
    devices_payload = await cache.get_or_set(
        "devices",
        lambda: client.list_devices(
            host_ids=host_ids,
            since_days=settings.unifi_device_window_days,
        ),
    )
    return hosts, sites, devices_payload


@router.get("/search")
async def search_devices(
    q: str | None = Query(default=None),
    site_id: str | None = Query(default=None),
    host_id: str | None = Query(default=None),
    limit: int = Query(default=500, ge=1, le=2000),
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    hosts, sites, devices_payload = await _load_all(db)
    devices = _flatten_devices(hosts, devices_payload, sites)

    if host_id:
        devices = [d for d in devices if d["host_id"] == host_id]
    if site_id:
        devices = [d for d in devices if d["site_id"] == site_id]

    needle = (q or "").strip().lower()
    if needle:
        devices = [d for d in devices if _matches(d, needle)]

    return {
        "total_hosts": len(hosts),
        "total_sites": len(sites),
        "total_devices": len(devices),
        "devices": devices[:limit],
        "cache": _cache_info(),
    }


@router.post("/refresh")
async def refresh_cache(_: User = Depends(require("devices:read"))):
    cache.invalidate()
    return {"ok": True}


def _sample(payload, limit: int = 2):
    """Return a trimmed sample so the debug blob stays small."""
    if isinstance(payload, list):
        return payload[:limit]
    if isinstance(payload, dict):
        data = payload.get("data")
        if isinstance(data, list):
            return {**{k: v for k, v in payload.items() if k != "data"}, "data": data[:limit]}
    return payload


@router.get("/_debug")
async def debug_raw(
    _: User = Depends(require("settings:manage")),
    db: Session = Depends(get_session),
):
    """Return trimmed raw responses from each upstream call. Admin-only."""
    hosts, sites, devices_payload = await _load_all(db)
    return {
        "hosts": {
            "count": len(hosts),
            "sample": _sample(hosts, 2),
            "sample_top_keys": sorted((hosts[0].keys() if hosts else [])),
            "sample_reported_state_keys": sorted(
                (hosts[0].get("reportedState", {}).keys() if hosts and isinstance(hosts[0].get("reportedState"), dict) else [])
            ),
        },
        "sites": {
            "count": len(sites),
            "sample": _sample(sites, 3),
            "sample_top_keys": sorted((sites[0].keys() if sites else [])),
        },
        "devices": {
            "count_hosts": len(devices_payload),
            "total_devices": sum(len(e.get("devices", [])) for e in devices_payload),
            "sample_entry_top_keys": sorted(devices_payload[0].keys()) if devices_payload else [],
            "sample_device_top_keys": sorted(
                devices_payload[0]["devices"][0].keys()
            ) if devices_payload and devices_payload[0].get("devices") else [],
            "sample_entry": _sample(devices_payload, 1),
        },
        "settings": {
            "base_url": settings.unifi_base_url,
            "prefix": settings.unifi_api_prefix,
            "device_window_days": settings.unifi_device_window_days,
        },
    }


@router.get("/sites")
async def list_sites(
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    _, sites, _payload = await _load_all(db)
    devices = _flatten_devices([], _payload, sites) if _payload else []
    devices_by_site: dict[str, int] = defaultdict(int)
    for d in devices:
        if d["site_id"]:
            devices_by_site[d["site_id"]] += 1
    return [
        {**_summarize_site(s), "device_count": devices_by_site.get(_site_id(s), 0)}
        for s in sites
    ]


@router.get("/hosts")
async def list_hosts(
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    hosts, sites, devices_payload = await _load_all(db)

    sites_by_host: dict[str, int] = defaultdict(int)
    for s in sites:
        hid = s.get("hostId")
        if hid:
            sites_by_host[hid] += 1

    devices_by_host: dict[str, int] = defaultdict(int)
    for entry in devices_payload:
        hid = entry.get("hostId")
        if hid:
            devices_by_host[hid] = len(entry.get("devices", []))

    out: list[dict] = []
    for h in hosts:
        summary = _summarize_host(h)
        hid = summary["id"]
        out.append(
            {
                **summary,
                "site_count": sites_by_host.get(hid, 0),
                "device_count": devices_by_host.get(hid, 0),
            }
        )
    return out


@router.get("/hosts/{host_id}")
async def host_detail(
    host_id: str,
    _: User = Depends(require("devices:read")),
    db: Session = Depends(get_session),
):
    hosts, sites, devices_payload = await _load_all(db)
    host = next((h for h in hosts if _host_id_of(h) == host_id), None)
    if not host:
        raise HTTPException(404, "Host not found")

    host_sites = [s for s in sites if s.get("hostId") == host_id]
    site_by_id = {sid: s for s in host_sites if (sid := _site_id(s))}

    links = _console_links(host_id, _host_meta(host))
    host_name = _host_name(host)

    entry = next((e for e in devices_payload if e.get("hostId") == host_id), None)
    raw_devices = entry.get("devices", []) if entry else []
    flat = [
        _flatten_device(d, host, host_id, host_name, links, site_by_id)
        for d in raw_devices
    ]

    grouped: dict[str | None, list[dict]] = defaultdict(list)
    for d in flat:
        grouped[d["site_id"]].append(d)

    site_entries: list[dict] = []
    for s in host_sites:
        sid = _site_id(s)
        site_entries.append(
            {
                **_summarize_site(s),
                "devices": grouped.get(sid, []),
                "device_count": len(grouped.get(sid, [])),
            }
        )
    # devices without a matching site
    unassigned = grouped.get(None, [])
    if unassigned:
        site_entries.append(
            {
                "id": None,
                "name": "(unassigned)",
                "host_id": host_id,
                "statistics": None,
                "devices": unassigned,
                "device_count": len(unassigned),
            }
        )

    return {
        "host": {**_summarize_host(host), "host_ip": links["host_ip"]},
        "sites": site_entries,
        "total_devices": len(flat),
    }
