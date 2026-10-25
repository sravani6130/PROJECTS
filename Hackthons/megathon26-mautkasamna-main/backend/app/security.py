"""Identifiers, tokens and password hashing.

- Student IDs are random and carry no meaning (not derived from the code,
  device or time). They are shown on the dashboard.
- Student tokens and dashboard sessions are 256-bit random secrets. Only
  their SHA-256 digests are stored, so a database leak does not leak usable
  credentials. Tokens are never logged.
- Dashboard passwords use scrypt with a per-user salt.
"""

from __future__ import annotations

import hashlib
import hmac
import secrets

# Crockford base32 without I, L, O, U: easy to read aloud, no lookalikes.
_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

STUDENT_TOKEN_PREFIX = "gst_"
SESSION_PREFIX = "gds_"


def new_student_id() -> str:
    """e.g. `STU-7KQ2-M9XD` (40 random bits)."""
    chars = "".join(secrets.choice(_ALPHABET) for _ in range(8))
    return f"STU-{chars[:4]}-{chars[4:]}"


def new_student_token() -> str:
    return STUDENT_TOKEN_PREFIX + secrets.token_urlsafe(32)


def new_session_token() -> str:
    return SESSION_PREFIX + secrets.token_urlsafe(32)


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def hash_password(password: str, *, salt: bytes | None = None) -> str:
    salt = salt or secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode("utf-8"), salt=salt, n=2**14, r=8, p=1, dklen=32)
    return f"scrypt${salt.hex()}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        scheme, salt_hex, digest_hex = stored.split("$")
    except ValueError:
        return False
    if scheme != "scrypt":
        return False
    candidate = hash_password(password, salt=bytes.fromhex(salt_hex)).split("$")[2]
    return hmac.compare_digest(candidate, digest_hex)


# Used when a username does not exist, so sign-in takes the same time
# whether or not the account exists.
DUMMY_PASSWORD_HASH = hash_password("not-a-real-password")
