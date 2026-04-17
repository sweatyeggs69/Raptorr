"""Symmetric encryption for secrets stored in the database.

A Fernet key is derived from the application SECRET_KEY via HKDF so the
key material never lands in the database and rotating SECRET_KEY rotates
the encryption key. Ciphertext is prefixed with a version tag (`v1:`)
so legacy plaintext values written before encryption was introduced are
still readable; any write re-encrypts them.
"""

from __future__ import annotations

import base64

from cryptography.fernet import Fernet, InvalidToken
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

from .config import settings

VERSION_PREFIX = "v1:"
_PURPOSE = b"raptorr:secrets:v1"


def _derive_fernet_key(secret: str) -> bytes:
    raw = HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=None,
        info=_PURPOSE,
    ).derive(secret.encode("utf-8"))
    return base64.urlsafe_b64encode(raw)


_cipher = Fernet(_derive_fernet_key(settings.secret_key))


def encrypt(plaintext: str) -> str:
    if not plaintext:
        return plaintext
    token = _cipher.encrypt(plaintext.encode("utf-8")).decode("utf-8")
    return VERSION_PREFIX + token


def decrypt(value: str) -> str:
    if not value:
        return value
    if value.startswith(VERSION_PREFIX):
        try:
            return _cipher.decrypt(value[len(VERSION_PREFIX):].encode("utf-8")).decode(
                "utf-8"
            )
        except InvalidToken:
            # Corrupted ciphertext or SECRET_KEY mismatch. Raise so the caller
            # surfaces a clear error rather than leaking the raw blob.
            raise
    # Legacy plaintext written before encryption was introduced.
    return value


def is_encrypted(value: str) -> bool:
    return bool(value) and value.startswith(VERSION_PREFIX)
