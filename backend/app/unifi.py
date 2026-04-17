import asyncio
import time
from typing import Any

import httpx
from fastapi import HTTPException
from sqlmodel import Session, select

from .config import settings
from .models import AppSetting

API_KEY_SETTING = "unifi_api_key"


def get_api_key(db: Session) -> str:
    row = db.get(AppSetting, API_KEY_SETTING)
    if not row or not row.value:
        raise HTTPException(
            status_code=409,
            detail="UniFi API key not configured. Set it in Settings.",
        )
    return row.value


def set_api_key(db: Session, value: str) -> None:
    row = db.get(AppSetting, API_KEY_SETTING)
    if row:
        row.value = value
    else:
        row = AppSetting(key=API_KEY_SETTING, value=value)
    db.add(row)
    db.commit()


def has_api_key(db: Session) -> bool:
    row = db.get(AppSetting, API_KEY_SETTING)
    return bool(row and row.value)


class UniFiClient:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = settings.unifi_base_url.rstrip("/") + settings.unifi_api_prefix

    async def _get(self, path: str, params: dict | None = None) -> dict:
        headers = {"X-API-Key": self.api_key, "Accept": "application/json"}
        async with httpx.AsyncClient(timeout=30, headers=headers) as client:
            try:
                r = await client.get(self.base_url + path, params=params)
            except httpx.RequestError as exc:
                raise HTTPException(502, f"UniFi API unreachable: {exc}") from exc
            if r.status_code == 401 or r.status_code == 403:
                raise HTTPException(401, "UniFi API key rejected")
            if r.status_code == 429:
                raise HTTPException(429, "UniFi API rate limit hit")
            if r.status_code >= 400:
                raise HTTPException(
                    502, f"UniFi API error {r.status_code}: {r.text[:200]}"
                )
            return r.json()

    async def list_hosts(self) -> list[dict]:
        results: list[dict] = []
        next_token: str | None = None
        while True:
            params: dict[str, Any] = {"pageSize": 100}
            if next_token:
                params["nextToken"] = next_token
            data = await self._get("/hosts", params=params)
            results.extend(data.get("data", []))
            next_token = data.get("nextToken")
            if not next_token:
                break
        return results

    async def list_sites(self) -> list[dict]:
        results: list[dict] = []
        next_token: str | None = None
        while True:
            params: dict[str, Any] = {"pageSize": 100}
            if next_token:
                params["nextToken"] = next_token
            data = await self._get("/sites", params=params)
            results.extend(data.get("data", []))
            next_token = data.get("nextToken")
            if not next_token:
                break
        return results

    async def list_devices(self, host_ids: list[str] | None = None) -> list[dict]:
        params: dict[str, Any] = {}
        if host_ids:
            params["hostIds[]"] = host_ids
        data = await self._get("/devices", params=params)
        return data.get("data", [])

    async def test(self) -> bool:
        await self._get("/hosts", params={"pageSize": 1})
        return True


class _Cache:
    def __init__(self, ttl: int):
        self.ttl = ttl
        self._store: dict[str, tuple[float, Any]] = {}
        self._lock = asyncio.Lock()

    async def get_or_set(self, key: str, factory):
        async with self._lock:
            now = time.time()
            entry = self._store.get(key)
            if entry and now - entry[0] < self.ttl:
                return entry[1]
        value = await factory()
        async with self._lock:
            self._store[key] = (time.time(), value)
        return value

    def invalidate(self, prefix: str = "") -> None:
        if not prefix:
            self._store.clear()
        else:
            for k in list(self._store.keys()):
                if k.startswith(prefix):
                    del self._store[k]


cache = _Cache(settings.cache_ttl_seconds)
