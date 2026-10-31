"""Счётчики лимитов в кеше (Redis) с фиксированным окном.

DRF-троттлинг считает по пользователю или IP; здесь ключи произвольные (IP+email, подсеть, email),
поэтому лимиты auth-эндпоинтов проверяются этим модулем.
"""

import hashlib
import ipaddress

from django.core.cache import cache
from rest_framework.exceptions import Throttled
from rest_framework.throttling import BaseThrottle


def client_ip(request) -> str:
    """IP клиента с учётом REST_FRAMEWORK["NUM_PROXIES"]."""
    return BaseThrottle().get_ident(request)


def subnet(ip: str) -> str:
    try:
        addr = ipaddress.ip_address(ip)
    except ValueError:
        return ip
    prefix = 24 if addr.version == 4 else 48
    return str(ipaddress.ip_network(f"{ip}/{prefix}", strict=False))


def digest(value: str) -> str:
    """Email и другие ПД не попадают в ключи Redis в открытом виде."""
    return hashlib.sha256(value.encode()).hexdigest()[:32]


def _key(scope: str, ident: str) -> str:
    return f"rl:{scope}:{ident}"


def hit(scope: str, ident: str, limit: int, window: int) -> bool:
    """Учитывает попытку. False — лимит превышен."""
    key = _key(scope, ident)
    cache.add(key, 0, timeout=window)
    try:
        count = cache.incr(key)
    except ValueError:  # ключ истёк между add и incr
        cache.set(key, 1, timeout=window)
        count = 1
    return count <= limit


def enforce(scope: str, ident: str, limit: int, window: int) -> None:
    if not hit(scope, ident, limit, window):
        raise Throttled(wait=window)


def count(scope: str, ident: str) -> int:
    return cache.get(_key(scope, ident), 0)


def reset(scope: str, ident: str) -> None:
    cache.delete(_key(scope, ident))
