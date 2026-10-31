"""Одноразовые 6-значные коды: в БД — HMAC, не более 5 попыток, TTL 15 минут."""

import hashlib
import hmac
import secrets
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.db.models import F
from django.utils import timezone

from .models import OneTimeCode

RESEND_COOLDOWN = timedelta(seconds=60)
MAX_CODES_PER_DAY = 5


class CodeError(Exception):
    pass


def _hash(code_id, code: str) -> str:
    return hmac.new(settings.SECRET_KEY.encode(), f"{code_id}:{code}".encode(), hashlib.sha256).hexdigest()


def can_issue(user, purpose) -> bool:
    """Не чаще раза в 60 с и не более 5 раз в сутки на пользователя и назначение."""
    now = timezone.now()
    recent = OneTimeCode.objects.filter(user=user, purpose=purpose, created_at__gte=now - timedelta(days=1))
    if recent.filter(created_at__gte=now - RESEND_COOLDOWN).exists():
        return False
    return recent.count() < MAX_CODES_PER_DAY


@transaction.atomic
def issue(user, purpose, *, target_email="") -> str:
    """Создаёт код и гасит предыдущие активные коды того же назначения. Возвращает код в открытом виде."""
    now = timezone.now()
    OneTimeCode.objects.filter(user=user, purpose=purpose, consumed_at__isnull=True).update(consumed_at=now)
    code = f"{secrets.randbelow(10**6):06d}"
    otc = OneTimeCode(
        user=user,
        purpose=purpose,
        target_email=target_email,
        expires_at=now + timedelta(seconds=settings.ONE_TIME_CODE_TTL),
    )
    otc.code_hash = _hash(otc.pk, code)
    otc.save()
    return code


def consume(user, purpose, code: str) -> OneTimeCode:
    """Проверяет и гасит код. Каждая неверная попытка учитывается; после лимита код недействителен."""
    with transaction.atomic():
        otc = (
            OneTimeCode.objects.select_for_update()
            .filter(user=user, purpose=purpose, consumed_at__isnull=True, expires_at__gt=timezone.now())
            .order_by("-created_at")
            .first()
        )
        if otc is None or otc.attempts >= settings.ONE_TIME_CODE_MAX_ATTEMPTS:
            raise CodeError("expired")
        if hmac.compare_digest(otc.code_hash, _hash(otc.pk, str(code))):
            otc.consumed_at = timezone.now()
            otc.save(update_fields=["consumed_at"])
            return otc
        OneTimeCode.objects.filter(pk=otc.pk).update(attempts=F("attempts") + 1)
    raise CodeError("invalid")
