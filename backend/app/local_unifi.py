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
        ctype = r.headers.get("content-type", "").lower()
        body_preview = r.text[:160].replace("\n", " ")
        if "text/html" in ctype or body_preview.lstrip().lower().startswith("<!doctype") \
                or body_preview.lstrip().startswith("<html"):
            hint = ""
            if "unifi.ui.com" in url or "api.ui.com/proxy/consoles" in url:
                hint = (
                    " The unifi.ui.com cloud proxy only accepts browser session "
                    "cookies, not the Control Plane API key. Use the console's LAN "
                    "URL (e.g. https://<console-ip>) instead, or put Raptorr on a "
                    "network that can reach it."
                )
            raise IntegrationError(
                f"Got an HTML login page instead of JSON from {url}."
                f" The API key was not accepted at this base URL.{hint}",
                status=r.status_code,
            )
        try:
            return r.json()
        except ValueError as exc:
            raise IntegrationError(
                f"Non-JSON response from {url}: {body_preview}"
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
    """Ordered list of URL candidates to try for a given console.

    LAN first because the Control Plane API key is only honored on the
    console's local endpoint. The `unifi.ui.com`/`api.ui.com` proxy paths are
    included for completeness but they require browser session cookies, not
    the API key — they'll return an HTML login page.
    """
    candidates: list[dict[str, Any]] = []
    if host_ip:
        candidates.append(
            {
                "label": f"LAN ({host_ip}) — recommended",
                "base_url": f"https://{host_ip}",
                "verify_tls": False,
            }
        )
    candidates.extend(
        [
            {
                "label": "Cloud proxy (unifi.ui.com) — browser-only, won't accept API key",
                "base_url": f"https://unifi.ui.com/proxy/consoles/{host_id}",
                "verify_tls": True,
            },
            {
                "label": "Cloud proxy (api.ui.com) — browser-only, won't accept API key",
                "base_url": f"https://api.ui.com/proxy/consoles/{host_id}",
                "verify_tls": True,
            },
        ]
    )
    return candidates
