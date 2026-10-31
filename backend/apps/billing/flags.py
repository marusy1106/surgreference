"""Серверные feature flags. Клиент получает вычисленные значения через /api/v1/app/config."""

import hashlib

from django.core.cache import cache

MONETIZATION_ENABLED = "monetization_enabled"
LEADERBOARDS_ENABLED = "leaderboards_enabled"
CASES_ENABLED = "cases_enabled"
REGISTRATION_CAPTCHA = "registration_captcha"
CERTIFICATE_PINNING = "certificate_pinning"
UNIVERSITY_VERIFICATION = "university_verification"

_CACHE_KEY = "billing:feature_flags:v1"
_CACHE_TTL = 60


def _load() -> dict[str, dict]:
    data = cache.get(_CACHE_KEY)
    if data is None:
        from .models import FeatureFlag

        data = {
            f.key: {
                "enabled": f.enabled,
                "rollout": f.rollout_percent,
                "rules": f.rules,
                "public": f.is_public,
            }
            for f in FeatureFlag.objects.all()
        }
        cache.set(_CACHE_KEY, data, _CACHE_TTL)
    return data


def invalidate_cache() -> None:
    cache.delete(_CACHE_KEY)


def _bucket(key: str, user_id) -> int:
    digest = hashlib.sha256(f"{key}:{user_id}".encode()).digest()
    return int.from_bytes(digest[:4], "big") % 100


def _evaluate(key: str, flag: dict | None, user) -> bool:
    if not flag or not flag["enabled"]:
        return False
    is_authenticated = bool(user and getattr(user, "is_authenticated", False))
    if flag["rules"].get("staff_only") and not (is_authenticated and user.is_staff):
        return False
    if flag["rollout"] >= 100:
        return True
    if not is_authenticated:
        return False
    return _bucket(key, user.pk) < flag["rollout"]


def is_enabled(key: str, user=None) -> bool:
    return _evaluate(key, _load().get(key), user)


def public_flags(user=None) -> dict[str, bool]:
    return {key: _evaluate(key, flag, user) for key, flag in _load().items() if flag["public"]}
