"""Client for the UniFi Network Integration API (local per-console).

Typical base URL patterns:
  https://<console-ip>                                   (direct LAN)
  https://unifi.ui.com/proxy/consoles/<hostId>           (cloud proxy)
  https://api.ui.com/proxy/consoles/<hostId>             (cloud proxy alt)

All three share the same path suffix: /proxy/network/integration/v1/...
and authenticate via the X-API-KEY header (the Control Plane local API key).
"""

from __future__ import annotations

from typing import Any

import httpx


INTEGRATION_PREFIX = "/proxy/network/integration/v1"


class IntegrationError(Exception):
    def __init__(self, message: str, status: int | None = None):
        super().__init__(message)
        self.status = status


class LocalUniFiClient:
    def __init__(self, base_url: str, api_key: str, verify_tls: bool = False):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.verify_tls = verify_tls

    def _url(self, path: str) -> str:
        if not path.startswith("/"):
            path = "/" + path
        return f"{self.base_url}{INTEGRATION_PREFIX}{path}"

    async def _get(self, path: str, params: dict | None = None) -> dict:
        headers = {"X-API-KEY": self.api_key, "Accept": "application/json"}
        url = self._url(path)
        try:
            async with httpx.AsyncClient(
                timeout=30,
                headers=headers,
                verify=self.verify_tls,
                follow_redirects=True,
            ) as client:
                r = await client.get(url, params=params)
        except httpx.RequestError as exc:
            raise IntegrationError(f"Unreachable: {exc}") from exc
        if r.status_code == 401 or r.status_code == 403:
            raise IntegrationError(
                f"Authentication rejected (HTTP {r.status_code}). "
                "Check that this is a Control Plane local API key and the base URL is correct.",
                status=r.status_code,
            )
        if r.status_code == 404:
            raise IntegrationError(
                f"Endpoint not found at {url}. "
                "This base URL may not expose the Network Integration API for this console.",
                status=404,
            )
        if r.status_code >= 400:
            raise IntegrationError(
                f"HTTP {r.status_code}: {r.text[:300]}", status=r.status_code
            )
        try:
            return r.json()
        except ValueError as exc:
            raise IntegrationError(
                f"Non-JSON response from {url}: {r.text[:200]}"
            ) from exc

    async def _get_paginated(
        self, path: str, page_size: int = 200
    ) -> list[dict]:
        results: list[dict] = []
        offset = 0
        while True:
            data = await self._get(
                path, params={"offset": offset, "limit": page_size}
            )
            items = data.get("data") or []
            results.extend(items)
            total = data.get("totalCount")
            fetched = offset + len(items)
            if not items or len(items) < page_size:
                break
            if isinstance(total, int) and fetched >= total:
                break
            offset = fetched
            if offset > 20000:  # safety valve
                break
        return results

    async def test(self) -> dict:
        data = await self._get("/sites", params={"offset": 0, "limit": 5})
        sites = data.get("data") or []
        total = data.get("totalCount") if isinstance(data.get("totalCount"), int) else len(sites)
        first = None
        if sites:
            s = sites[0]
            first = s.get("name") or s.get("internalReference") or s.get("id")
        return {
            "endpoint": self._url("/sites"),
            "site_count": total,
            "first_site_name": first,
        }

    async def list_sites(self) -> list[dict]:
        return await self._get_paginated("/sites")

    async def list_devices(self, site_id: str) -> list[dict]:
        return await self._get_paginated(f"/sites/{site_id}/devices")

    async def list_clients(self, site_id: str) -> list[dict]:
        return await self._get_paginated(f"/sites/{site_id}/clients")


def mask_key(key: str) -> str:
    if not key:
        return ""
    if len(key) <= 8:
        return "*" * len(key)
    return key[:4] + "…" + key[-4:]


def suggest_base_urls(host_id: str, host_ip: str | None = None) -> list[dict[str, Any]]:
    """Ordered list of URL candidates to try for a given console."""
    candidates: list[dict[str, Any]] = [
        {
            "label": "Cloud proxy (unifi.ui.com)",
            "base_url": f"https://unifi.ui.com/proxy/consoles/{host_id}",
            "verify_tls": True,
        },
        {
            "label": "Cloud proxy (api.ui.com)",
            "base_url": f"https://api.ui.com/proxy/consoles/{host_id}",
            "verify_tls": True,
        },
    ]
    if host_ip:
        candidates.append(
            {
                "label": f"LAN ({host_ip})",
                "base_url": f"https://{host_ip}",
                "verify_tls": False,
            }
        )
    return candidates
