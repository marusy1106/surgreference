"""Сценарии авторизации (docs/04-auth-security.md, 4.1–4.7).

Письма отправляются после выхода из транзакций: код не уходит пользователю, если запись откатилась.
"""

import json
import uuid
from dataclasses import dataclass
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import password_validation
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework.exceptions import AuthenticationFailed, Throttled, ValidationError

from apps.audit.models import SecurityEvent
from apps.audit.services import record_security_event
from apps.core import ratelimit

from . import codes, emails, tokens
from .disposable import is_disposable_email
from .models import Consent, DataSubjectRequest, OneTimeCode, User, UserSession
from .selectors import active_sessions
from .signals import account_deleted, export_requested

FAILURE = SecurityEvent.Outcome.FAILURE
REQUIRED_CONSENTS = (Consent.Document.PD_PROCESSING, Consent.Document.TERMS, Consent.Document.PRIVACY_POLICY)
HOUR, DAY = 3600, 24 * 3600


@dataclass(frozen=True)
class Device:
    platform: str
    device_name: str = ""
    app_version: str = ""


def _invalid_code():
    return ValidationError({"code": ["Неверный или просроченный код"]}, code="invalid_code")


def _validate_password(password, user, field="password"):
    """Политика пароля Django → ошибка поля в едином формате API."""
    try:
        password_validation.validate_password(password, user)
    except DjangoValidationError as exc:
        raise ValidationError({field: list(exc.messages)}) from None


# --- Сессии и токены ----------------------------------------------------------


def _token_pair(user, session, refresh):
    return {
        "access": tokens.issue_access_token(user, session),
        "refresh": refresh,
        "token_type": "Bearer",
        "expires_in": settings.ACCESS_TOKEN_TTL,
        "session_id": session.pk,
        "user": user,
    }


def _revoke(sessions, reason):
    ids = list(sessions.filter(revoked_at__isnull=True).values_list("pk", flat=True))
    UserSession.objects.filter(pk__in=ids).update(revoked_at=timezone.now(), revoke_reason=reason)
    tokens.denylist_sessions(ids)
    return len(ids)


def start_session(user, device: Device, ip):
    now = timezone.now()
    refresh = tokens.new_refresh_token()
    with transaction.atomic():
        session = UserSession.objects.create(
            user=user,
            refresh_token_hash=tokens.hash_refresh_token(refresh),
            family_id=uuid.uuid4(),
            platform=device.platform,
            device_name=device.device_name[:64],
            app_version=device.app_version[:32],
            ip_last=ip,
            expires_at=now + timedelta(seconds=settings.REFRESH_TOKEN_SLIDING_TTL),
            absolute_expires_at=now + timedelta(seconds=settings.REFRESH_TOKEN_ABSOLUTE_TTL),
        )
        active = UserSession.objects.filter(user=user, revoked_at__isnull=True, expires_at__gt=now)
        overflow = active.order_by("-last_used_at").values_list("pk", flat=True)[settings.MAX_ACTIVE_SESSIONS :]
        _revoke(UserSession.objects.filter(pk__in=list(overflow)), "evicted")
    User.objects.filter(pk=user.pk).update(last_login=now)
    return _token_pair(user, session, refresh)


def refresh_session(refresh, request):
    """Ротация: новая пара токенов, старый refresh становится недействительным."""
    token_hash = tokens.hash_refresh_token(refresh)
    now = timezone.now()
    reused = None
    with transaction.atomic():
        session = (
            UserSession.objects.select_for_update()
            .select_related("user")
            .filter(refresh_token_hash=token_hash, revoked_at__isnull=True)
            .first()
        )
        if session is None:
            reused = UserSession.objects.filter(previous_refresh_hash=token_hash, revoked_at__isnull=True).first()
            if reused is not None:
                _revoke(UserSession.objects.filter(pk=reused.pk), "refresh_reuse")
        elif session.expires_at > now and session.user.is_active:
            new_refresh = tokens.new_refresh_token()
            session.previous_refresh_hash = token_hash
            session.refresh_token_hash = tokens.hash_refresh_token(new_refresh)
            session.expires_at = min(
                now + timedelta(seconds=settings.REFRESH_TOKEN_SLIDING_TTL), session.absolute_expires_at
            )
            session.last_used_at = now
            session.ip_last = ratelimit.client_ip(request)
            session.save(
                update_fields=[
                    "previous_refresh_hash",
                    "refresh_token_hash",
                    "expires_at",
                    "last_used_at",
                    "ip_last",
                    "updated_at",
                ]
            )
            return _token_pair(session.user, session, new_refresh)

    if reused is not None:
        record_security_event(
            "auth.refresh_reuse", outcome=FAILURE, request=request, actor=reused.user, session_id=str(reused.pk)
        )
        emails.session_family_revoked(reused.user.email)
    raise AuthenticationFailed("Сессия недействительна, войдите заново", code="refresh_invalid")


def revoke_session(user, session_id, *, request=None):
    count = _revoke(UserSession.objects.filter(user=user, pk=session_id), "user")
    if count:
        record_security_event("auth.session_revoked", request=request, actor=user, session_id=str(session_id))
    return count


def revoke_other_sessions(user, current_sid, *, request=None):
    count = _revoke(UserSession.objects.filter(user=user).exclude(pk=current_sid), "user")
    record_security_event("auth.sessions_revoked", request=request, actor=user, count=count)
    return count


# --- Регистрация и подтверждение email -------------------------------------------


def register(*, email, password, display_name, consents, request):
    """Ответ одинаков, есть такой email или нет (защита от перебора адресов)."""
    ip = ratelimit.client_ip(request)
    ratelimit.enforce("register-ip", ip, 3, HOUR)
    ratelimit.enforce("register-subnet", ratelimit.subnet(ip), 20, DAY)

    email = User.objects.normalize_email(email)
    if is_disposable_email(email):
        raise ValidationError({"email": ["Одноразовые почтовые ящики не поддерживаются"]})
    accepted = {c["document"]: c["version"] for c in consents}
    for document in REQUIRED_CONSENTS:
        if accepted.get(document) != settings.LEGAL_DOCUMENT_VERSIONS[document]:
            raise ValidationError({"consents": [f"Нужно принять актуальную версию документа: {document}"]})

    existing = User.objects.filter(email=email).first()
    if existing is not None:
        if existing.is_active:
            emails.registration_attempt(email)
        record_security_event(
            "auth.register", outcome=FAILURE, request=request, subject=existing, reason="email_exists"
        )
        return

    if User.objects.filter(display_name__iexact=display_name).exists():
        raise ValidationError({"display_name": ["Этот никнейм уже занят"]})
    user = User(email=email, display_name=display_name)
    _validate_password(password, user)
    user.set_password(password)
    try:
        with transaction.atomic():
            user.save()
            Consent.objects.bulk_create(
                Consent(user=user, document=doc, document_version=version, ip=ip)
                for doc, version in accepted.items()
                if doc in Consent.Document.values
            )
            code = codes.issue(user, OneTimeCode.Purpose.VERIFY_EMAIL)
    except IntegrityError:
        # Гонка двух регистраций с одним email/никнеймом.
        raise ValidationError({"display_name": ["Этот никнейм уже занят"]}) from None
    emails.verification_code(email, code)
    record_security_event("auth.register", request=request, actor=user)


def resend_verification(email, request):
    ratelimit.enforce("resend-ip", ratelimit.client_ip(request), 10, HOUR)
    user = User.objects.filter(
        email=User.objects.normalize_email(email), is_active=True, email_verified_at__isnull=True
    ).first()
    if user is None or not codes.can_issue(user, OneTimeCode.Purpose.VERIFY_EMAIL):
        return
    emails.verification_code(user.email, codes.issue(user, OneTimeCode.Purpose.VERIFY_EMAIL))


def verify_email(*, email, code, device: Device, request):
    ratelimit.enforce("verify-ip", ratelimit.client_ip(request), 10, HOUR)
    user = User.objects.filter(
        email=User.objects.normalize_email(email), is_active=True, email_verified_at__isnull=True
    ).first()
    if user is None:
        raise _invalid_code()
    try:
        codes.consume(user, OneTimeCode.Purpose.VERIFY_EMAIL, code)
    except codes.CodeError:
        record_security_event("auth.verify_email", outcome=FAILURE, request=request, subject=user)
        raise _invalid_code() from None
    user.email_verified_at = timezone.now()
    user.save(update_fields=["email_verified_at", "updated_at"])
    record_security_event("auth.verify_email", request=request, actor=user)
    return start_session(user, device, ratelimit.client_ip(request))


# --- Вход ----------------------------------------------------------------------


def login(*, email, password, device: Device, request):
    ip = ratelimit.client_ip(request)
    email = User.objects.normalize_email(email)
    key = ratelimit.digest(email)
    ratelimit.enforce("login-ip-email", f"{ip}:{key}", 5, 60)
    ratelimit.enforce("login-email", key, 20, HOUR)
    if ratelimit.count("login-locked", key):
        raise Throttled(wait=settings.LOGIN_LOCKOUT_SECONDS)

    user = User.objects.filter(email=email).first()
    if user is None:
        User().set_password(password)  # выравниваем время ответа для несуществующих адресов
        ok = False
    else:
        ok = user.check_password(password) and user.is_active and user.deleted_at is None

    if not ok:
        _login_failed(user, key, request)
        raise AuthenticationFailed("Неверный email или пароль", code="invalid_credentials")

    ratelimit.reset("login-failures", key)
    record_security_event("auth.login", request=request, actor=user, platform=device.platform)
    return start_session(user, device, ip)


def _login_failed(user, key, request):
    record_security_event("auth.login", outcome=FAILURE, request=request, subject=user)
    failures_ok = ratelimit.hit("login-failures", key, settings.LOGIN_LOCKOUT_FAILURES - 1, HOUR)
    if not failures_ok:
        ratelimit.hit("login-locked", key, 1, settings.LOGIN_LOCKOUT_SECONDS)
        ratelimit.reset("login-failures", key)
        record_security_event("auth.login_locked", outcome=FAILURE, request=request, subject=user)
        if user is not None and user.is_active:
            emails.login_locked(user.email)


def logout(user, sid, *, request=None):
    _revoke(UserSession.objects.filter(user=user, pk=sid), "logout")
    record_security_event("auth.logout", request=request, actor=user)


# --- Пароль --------------------------------------------------------------------


def forgot_password(email, request):
    ratelimit.enforce("forgot-ip", ratelimit.client_ip(request), 10, HOUR)
    user = User.objects.filter(email=User.objects.normalize_email(email), is_active=True).first()
    if user is None or not codes.can_issue(user, OneTimeCode.Purpose.RESET_PASSWORD):
        return
    emails.password_reset_code(user.email, codes.issue(user, OneTimeCode.Purpose.RESET_PASSWORD))
    record_security_event("auth.password_reset_requested", request=request, subject=user)


def reset_password(*, email, code, new_password, request):
    ratelimit.enforce("reset-ip", ratelimit.client_ip(request), 10, HOUR)
    user = User.objects.filter(email=User.objects.normalize_email(email), is_active=True).first()
    if user is None:
        raise _invalid_code()
    _validate_password(new_password, user, "new_password")
    try:
        codes.consume(user, OneTimeCode.Purpose.RESET_PASSWORD, code)
    except codes.CodeError:
        record_security_event("auth.password_reset", outcome=FAILURE, request=request, subject=user)
        raise _invalid_code() from None
    _set_password(user, new_password, keep_sid=None, request=request, event="auth.password_reset")


def change_password(user, *, sid, old_password, new_password, request):
    if not user.check_password(old_password):
        record_security_event("auth.password_change", outcome=FAILURE, request=request, actor=user)
        raise ValidationError({"old_password": ["Неверный текущий пароль"]})
    _validate_password(new_password, user, "new_password")
    _set_password(user, new_password, keep_sid=sid, request=request, event="auth.password_change")


def _set_password(user, password, *, keep_sid, request, event):
    with transaction.atomic():
        user.set_password(password)
        user.save(update_fields=["password", "updated_at"])
        sessions = UserSession.objects.filter(user=user)
        if keep_sid:
            sessions = sessions.exclude(pk=keep_sid)
        _revoke(sessions, "password_changed")
    ratelimit.reset("login-locked", ratelimit.digest(user.email))
    record_security_event(event, request=request, actor=user)
    emails.password_changed(user.email)


# --- Удаление аккаунта и выгрузка данных (152-ФЗ) --------------------------------------------


def request_account_deletion(user, request):
    if not codes.can_issue(user, OneTimeCode.Purpose.DELETE_ACCOUNT):
        raise Throttled(wait=60)
    emails.deletion_code(user.email, codes.issue(user, OneTimeCode.Purpose.DELETE_ACCOUNT))


def delete_account(user, code, request):
    try:
        codes.consume(user, OneTimeCode.Purpose.DELETE_ACCOUNT, code)
    except codes.CodeError:
        raise _invalid_code() from None
    old_email = user.email
    anonymize(user, note="самообслуживание в приложении")
    record_security_event("account.deleted", request=request, actor=user)
    emails.account_deleted(old_email)


@transaction.atomic
def anonymize(user, *, note):
    """Обезличивание вместо удаления строки: учебная статистика и XP-журнал (append-only) остаются
    привязанными к UUID без ПД (docs/04, 4.7)."""
    now = timezone.now()
    _revoke(UserSession.objects.filter(user=user), "account_deleted")
    UserSession.objects.filter(user=user).delete()
    OneTimeCode.objects.filter(user=user).delete()
    Consent.objects.filter(user=user, withdrawn_at__isnull=True).update(withdrawn_at=now)

    user.email = f"deleted+{user.pk}@invalid"
    user.display_name = f"deleted_{user.pk.hex[:12]}"
    user.first_name = ""
    user.is_active = False
    user.leaderboard_opt_in = False
    user.deleted_at = now
    user.set_unusable_password()
    user.save()

    DataSubjectRequest.objects.create(
        user=user,
        kind=DataSubjectRequest.Kind.DELETE,
        status=DataSubjectRequest.Status.COMPLETED,
        received_at=now,
        due_at=now + timedelta(days=30),
        completed_at=now,
        note=note,
    )
    account_deleted.send(sender=User, user=user)


def request_data_export(user, request):
    if not ratelimit.hit("export", str(user.pk), 1, DAY):
        raise Throttled(wait=DAY)
    from .tasks import export_data

    record_security_event("account.export_requested", request=request, actor=user)
    export_data.delay(str(user.pk))


def build_export(user):
    data = {
        "generated_at": timezone.now().isoformat(),
        "profile": {
            "id": str(user.pk),
            "email": user.email,
            "display_name": user.display_name,
            "first_name": user.first_name,
            "email_verified_at": user.email_verified_at,
            "created_at": user.created_at,
            "leaderboard_opt_in": user.leaderboard_opt_in,
        },
        "consents": list(
            user.consents.values("document", "document_version", "accepted_at", "withdrawn_at").order_by("accepted_at")
        ),
        "sessions": list(
            active_sessions(user).values("platform", "device_name", "app_version", "created_at", "last_used_at")
        ),
    }
    for _receiver, section in export_requested.send(sender=User, user=user):
        if section:
            name, payload = section
            data[name] = payload
    return data


def send_data_export(user_id):
    user = User.objects.filter(pk=user_id, is_active=True).first()
    if user is None:
        return
    payload = json.dumps(build_export(user), ensure_ascii=False, indent=2, default=str)
    now = timezone.now()
    DataSubjectRequest.objects.create(
        user=user,
        kind=DataSubjectRequest.Kind.EXPORT,
        status=DataSubjectRequest.Status.COMPLETED,
        received_at=now,
        due_at=now + timedelta(days=10),
        completed_at=now,
        note="самообслуживание в приложении",
    )
    emails.data_export(user.email, payload)


# --- Обслуживание ----------------------------------------------------------------


def cleanup_expired():
    now = timezone.now()
    stale_unverified = User.objects.filter(
        email_verified_at__isnull=True,
        deleted_at__isnull=True,
        is_staff=False,
        created_at__lt=now - timedelta(days=settings.UNVERIFIED_ACCOUNT_TTL_DAYS),
    )
    count = 0
    for user in stale_unverified.iterator():
        anonymize(user, note="email не подтверждён в течение 7 дней")
        count += 1
    OneTimeCode.objects.filter(expires_at__lt=now - timedelta(days=1)).delete()
    UserSession.objects.filter(expires_at__lt=now - timedelta(days=30)).delete()
    UserSession.objects.filter(revoked_at__lt=now - timedelta(days=30)).delete()
    return count
