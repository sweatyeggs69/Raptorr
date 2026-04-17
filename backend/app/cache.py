"""Small async TTL cache with single-flight semantics."""

from __future__ import annotations

import asyncio
import time
from typing import Any


class TTLCache:
    def __init__(self, ttl: int):
        self.ttl = ttl
        self._store: dict[str, tuple[float, Any]] = {}
        self._inflight: dict[str, asyncio.Future] = {}
        self._lock = asyncio.Lock()

    async def get_or_set(self, key: str, factory):
        async with self._lock:
            now = time.time()
            entry = self._store.get(key)
            if entry and now - entry[0] < self.ttl:
                return entry[1]
            fut = self._inflight.get(key)
            owner = fut is None
            if owner:
                fut = asyncio.get_event_loop().create_future()
                self._inflight[key] = fut
        if owner:
            try:
                value = await factory()
            except BaseException as exc:
                async with self._lock:
                    self._inflight.pop(key, None)
                fut.set_exception(exc)
                # Fall through so `await fut` re-raises for the owner too,
                # which avoids a "Future exception was never retrieved" warning.
            else:
                async with self._lock:
                    self._store[key] = (time.time(), value)
                    self._inflight.pop(key, None)
                fut.set_result(value)
        return await fut

    def age(self, key: str) -> float | None:
        entry = self._store.get(key)
        if not entry:
            return None
        return time.time() - entry[0]

    def invalidate(self, prefix: str = "") -> None:
        if not prefix:
            self._store.clear()
        else:
            for k in list(self._store.keys()):
                if k.startswith(prefix):
                    del self._store[k]
