"""Access — короткоживущий JWT; refresh — случайные 256 бит, в БД хранится только SHA-256."""

import hashlib
import secrets
import time

import jwt
from django.conf import settings
from django.core.cache import cache

ALGORITHM = "HS256"
ACCESS_SCOPE = "access"


class InvalidToken(Exception):
    pass


def issue_access_token(user, session) -> str:
    now = int(time.time())
    payload = {
        "iss": settings.JWT_ISSUER,
        "sub": str(user.pk),
        "sid": str(session.pk),
        "scope": ACCESS_SCOPE,
        "iat": now,
        "exp": now + settings.ACCESS_TOKEN_TTL,
    }
    kid = settings.JWT_ACTIVE_KID
    return jwt.encode(payload, settings.JWT_SIGNING_KEYS[kid], algorithm=ALGORITHM, headers={"kid": kid})


def decode_access_token(token: str) -> dict:
    try:
        kid = jwt.get_unverified_header(token).get("kid")
        key = settings.JWT_SIGNING_KEYS.get(kid)
        if key is None:
            raise InvalidToken("unknown kid")
        payload = jwt.decode(
            token,
            key,
            algorithms=[ALGORITHM],
            issuer=settings.JWT_ISSUER,
            options={"require": ["exp", "iat", "sub", "sid", "scope"]},
        )
    except jwt.PyJWTError as exc:
        raise InvalidToken(str(exc)) from exc
    if payload["scope"] != ACCESS_SCOPE:
        raise InvalidToken("wrong scope")
    return payload


def new_refresh_token() -> str:
    return secrets.token_urlsafe(32)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


# Отзыв действует сразу: sid попадает в denylist на время жизни access-токена.
def _revoked_key(sid) -> str:
    return f"auth:revoked-sid:{sid}"


def denylist_sessions(session_ids) -> None:
    cache.set_many({_revoked_key(sid): 1 for sid in session_ids}, timeout=settings.ACCESS_TOKEN_TTL)


def is_session_denylisted(sid) -> bool:
    return cache.get(_revoked_key(sid)) is not None
