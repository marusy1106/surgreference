"""API-сценарии docs/04-auth-security.md, 4.1–4.10."""

import json
import time
from datetime import timedelta

import jwt
import pytest
from django.conf import settings
from django.utils import timezone

from apps.accounts import selectors, services
from apps.accounts.models import Consent, DataSubjectRequest, OneTimeCode, User, UserSession
from apps.audit.models import SecurityEvent

from .conftest import DEVICE, PASSWORD, code_from, consents

pytestmark = pytest.mark.django_db


def register(post, email="new@example.org", display_name="newbie", password="glass-river-1987", **kw):
    ip = kw.pop("ip", None)
    payload = {"email": email, "password": password, "display_name": display_name, "consents": consents()}
    return post("auth/register", {**payload, **kw}, ip=ip)


# --- 4.1 Регистрация и подтверждение email ---------------------------------------------


def test_register_sends_code_and_verify_returns_tokens(post, call, mailoutbox):
    response = register(post)
    assert response.status_code == 202
    assert response.json() == {"status": "verification_sent"}
    user = User.objects.get(email="new@example.org")
    assert not user.is_email_verified
    assert set(user.consents.values_list("document", flat=True)) == set(settings.LEGAL_DOCUMENT_VERSIONS)
    assert len(mailoutbox) == 1

    response = post(
        "auth/verify-email", {"email": "New@Example.org", "code": code_from(mailoutbox[0]), "device": DEVICE}
    )
    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email_verified"] is True
    assert body["expires_in"] == settings.ACCESS_TOKEN_TTL
    assert call("get", "me", body["access"]).json()["display_name"] == "newbie"


def test_register_existing_email_same_response_and_owner_notified(post, verified_user, mailoutbox):
    response = register(post, email=verified_user.email, display_name="someone")
    assert response.status_code == 202
    assert response.json() == {"status": "verification_sent"}
    assert not User.objects.filter(display_name="someone").exists()
    assert len(mailoutbox) == 1
    assert "Попытка регистрации" in mailoutbox[0].subject
    assert not OneTimeCode.objects.filter(user=verified_user).exists()


@pytest.mark.parametrize(
    ("override", "field"),
    [
        ({"password": "1234567890"}, "password"),
        ({"password": "short"}, "password"),
        ({"email": "bot@mailinator.com"}, "email"),
        ({"consents": [{"document": "terms", "version": "1.0"}]}, "consents"),
        ({"display_name": "a b"}, "display_name"),
    ],
)
def test_register_validation(post, override, field):
    response = register(post, **override)
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "validation_error"
    assert field in response.json()["error"]["fields"]


def test_register_password_similar_to_nickname_rejected(post):
    response = register(post, display_name="cardiosurgeon", password="cardiosurgeon1")
    assert response.status_code == 400
    assert "password" in response.json()["error"]["fields"]


def test_register_taken_display_name(post, verified_user):
    response = register(post, display_name="DOCTOR")
    assert response.status_code == 400
    assert "display_name" in response.json()["error"]["fields"]


def test_register_rate_limited_per_ip(post):
    for n in range(3):
        assert register(post, email=f"u{n}@example.org", display_name=f"user_{n}", ip="10.9.9.9").status_code == 202
    response = register(post, email="u4@example.org", display_name="user_4", ip="10.9.9.9")
    assert response.status_code == 429
    assert response.json()["error"]["code"] == "throttled"


def test_code_brute_force_blocked_after_five_attempts(post, mailoutbox):
    register(post)
    code = code_from(mailoutbox[0])
    wrong = f"{(int(code) + 1) % 10**6:06d}"
    for _ in range(settings.ONE_TIME_CODE_MAX_ATTEMPTS):
        response = post("auth/verify-email", {"email": "new@example.org", "code": wrong, "device": DEVICE})
        assert response.status_code == 400
    # Даже верный код больше не принимается.
    response = post("auth/verify-email", {"email": "new@example.org", "code": code, "device": DEVICE})
    assert response.status_code == 400
    assert response.json()["error"]["fields"]["code"]


def test_expired_code_rejected(post, mailoutbox):
    register(post)
    OneTimeCode.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
    response = post(
        "auth/verify-email", {"email": "new@example.org", "code": code_from(mailoutbox[0]), "device": DEVICE}
    )
    assert response.status_code == 400


def test_resend_respects_cooldown_and_replaces_code(post, mailoutbox):
    register(post)
    first = code_from(mailoutbox[0])
    assert post("auth/resend-code", {"email": "new@example.org"}).status_code == 202
    assert len(mailoutbox) == 1  # не чаще раза в 60 с

    OneTimeCode.objects.update(created_at=timezone.now() - timedelta(minutes=2))
    assert post("auth/resend-code", {"email": "new@example.org"}).status_code == 202
    assert len(mailoutbox) == 2
    response = post("auth/verify-email", {"email": "new@example.org", "code": first, "device": DEVICE})
    assert response.status_code == 400  # старый код погашен


def test_resend_unknown_email_same_response(post, mailoutbox):
    assert post("auth/resend-code", {"email": "ghost@example.org"}).status_code == 202
    assert mailoutbox == []


# --- Вход и блокировка --------------------------------------------------------------------


def test_login_wrong_password_and_unknown_email_look_the_same(post, verified_user):
    wrong = post("auth/login", {"email": verified_user.email, "password": "nope-nope-nope", "device": DEVICE})
    ghost = post("auth/login", {"email": "ghost@example.org", "password": "nope-nope-nope", "device": DEVICE})
    assert wrong.status_code == ghost.status_code == 401
    assert wrong.json() == ghost.json()
    assert wrong.json()["error"]["code"] == "invalid_credentials"
    assert SecurityEvent.objects.filter(event="auth.login", outcome="failure").count() == 2


def test_login_rate_limited_per_ip_and_email(post, verified_user):
    data = {"email": verified_user.email, "password": "nope-nope-nope", "device": DEVICE}
    codes = [post("auth/login", data, ip="10.7.7.7").status_code for _ in range(6)]
    assert codes == [401] * 5 + [429]


def test_login_locked_after_ten_failures_and_owner_notified(post, verified_user, mailoutbox):
    data = {"email": verified_user.email, "password": "nope-nope-nope", "device": DEVICE}
    for _ in range(settings.LOGIN_LOCKOUT_FAILURES):
        assert post("auth/login", data).status_code == 401
    response = post("auth/login", {**data, "password": PASSWORD})
    assert response.status_code == 429
    assert any("Подозрительные попытки" in m.subject for m in mailoutbox)
    assert SecurityEvent.objects.filter(event="auth.login_locked").exists()


def test_unverified_user_can_login(post, make_user, login):
    user = make_user()
    assert login(user)["user"]["email_verified"] is False


def test_inactive_user_cannot_login(post, make_user):
    user = make_user(is_active=False)
    response = post("auth/login", {"email": user.email, "password": PASSWORD, "device": DEVICE})
    assert response.status_code == 401


def test_login_upgrades_outdated_password_hash(post, make_user, settings):
    user = make_user()
    assert user.password.startswith("md5$")
    settings.PASSWORD_HASHERS = [
        "django.contrib.auth.hashers.PBKDF2PasswordHasher",
        "django.contrib.auth.hashers.MD5PasswordHasher",
    ]
    post("auth/login", {"email": user.email, "password": PASSWORD, "device": DEVICE})
    user.refresh_from_db()
    assert user.password.startswith("pbkdf2_sha256$")


# --- 4.3 Токены и сессии ----------------------------------------------------------


def test_requests_without_token_rejected(call):
    response = call("get", "me", None)
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_expired_or_forged_access_rejected(call, verified_user, login):
    tokens = login(verified_user)
    payload = jwt.decode(tokens["access"], options={"verify_signature": False})
    key = settings.JWT_SIGNING_KEYS[settings.JWT_ACTIVE_KID]
    expired = jwt.encode({**payload, "exp": int(time.time()) - 1}, key, headers={"kid": settings.JWT_ACTIVE_KID})
    forged = jwt.encode(payload, "attacker-key-" * 4, headers={"kid": settings.JWT_ACTIVE_KID})
    unknown_kid = jwt.encode(payload, key, headers={"kid": "old"})
    for token in (expired, forged, unknown_kid, tokens["refresh"]):
        response = call("get", "me", token)
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "token_invalid"


def test_refresh_rotates_tokens(post, call, verified_user, login):
    first = login(verified_user)
    response = post("auth/refresh", {"refresh": first["refresh"]})
    assert response.status_code == 200
    second = response.json()
    assert second["refresh"] != first["refresh"]
    assert second["session_id"] == first["session_id"]
    assert call("get", "me", second["access"]).status_code == 200


def test_refresh_reuse_revokes_session(post, call, verified_user, login, mailoutbox):
    first = login(verified_user)
    second = post("auth/refresh", {"refresh": first["refresh"]}).json()

    # Кто-то предъявил старый refresh — сессия отзывается целиком.
    response = post("auth/refresh", {"refresh": first["refresh"]})
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "refresh_invalid"
    assert post("auth/refresh", {"refresh": second["refresh"]}).status_code == 401
    assert call("get", "me", second["access"]).json()["error"]["code"] == "session_revoked"
    assert UserSession.objects.get(pk=first["session_id"]).revoke_reason == "refresh_reuse"
    assert SecurityEvent.objects.filter(event="auth.refresh_reuse").exists()
    assert any("по соображениям безопасности" in m.subject for m in mailoutbox)


def test_refresh_respects_absolute_lifetime(post, verified_user, login):
    tokens = login(verified_user)
    UserSession.objects.filter(pk=tokens["session_id"]).update(absolute_expires_at=timezone.now() + timedelta(hours=1))
    refreshed = post("auth/refresh", {"refresh": tokens["refresh"]}).json()
    session = UserSession.objects.get(pk=refreshed["session_id"])
    assert session.expires_at == session.absolute_expires_at

    UserSession.objects.filter(pk=session.pk).update(expires_at=timezone.now() - timedelta(seconds=1))
    assert post("auth/refresh", {"refresh": refreshed["refresh"]}).status_code == 401


def test_garbage_refresh_rejected(post):
    assert post("auth/refresh", {"refresh": "not-a-token"}).status_code == 401


def test_logout_revokes_immediately(post, call, verified_user, login):
    tokens = login(verified_user)
    assert post("auth/logout", token=tokens["access"]).status_code == 204
    assert call("get", "me", tokens["access"]).json()["error"]["code"] == "session_revoked"
    assert post("auth/refresh", {"refresh": tokens["refresh"]}).status_code == 401


def test_sessions_list_and_revoke(call, verified_user, login, session_for):
    current = login(verified_user)
    other = session_for(verified_user)

    sessions = call("get", "auth/sessions", current["access"]).json()
    assert len(sessions) == 2
    assert {s["is_current"] for s in sessions} == {True, False}
    assert all("refresh" not in key for s in sessions for key in s)

    assert call("delete", f"auth/sessions/{other['session_id']}", current["access"]).status_code == 204
    assert call("get", "me", other["access"]).status_code == 401
    assert call("get", "me", current["access"]).status_code == 200


def test_cannot_revoke_foreign_session(call, verified_user, make_user, login, session_for):
    mine = login(verified_user)
    foreign = session_for(make_user())
    assert call("delete", f"auth/sessions/{foreign['session_id']}", mine["access"]).status_code == 404
    assert call("get", "me", foreign["access"]).status_code == 200


def test_revoke_all_other_sessions(call, verified_user, login, session_for):
    current = login(verified_user)
    others = [session_for(verified_user) for _ in range(3)]
    assert call("delete", "auth/sessions", current["access"]).status_code == 204
    assert all(call("get", "me", o["access"]).status_code == 401 for o in others)
    assert call("get", "me", current["access"]).status_code == 200


def test_oldest_session_evicted_over_limit(verified_user, session_for):
    first = session_for(verified_user)
    UserSession.objects.filter(pk=first["session_id"]).update(last_used_at=timezone.now() - timedelta(days=1))
    for _ in range(settings.MAX_ACTIVE_SESSIONS):
        session_for(verified_user)
    assert selectors.active_sessions(verified_user).count() == settings.MAX_ACTIVE_SESSIONS
    assert UserSession.objects.get(pk=first["session_id"]).revoke_reason == "evicted"


# --- 4.2, 4.4 Пароль -----------------------------------------------------------------


def test_password_reset_flow(post, call, verified_user, login, mailoutbox):
    old = login(verified_user)
    assert post("auth/password/forgot", {"email": verified_user.email}).status_code == 202
    code = code_from(mailoutbox[-1])

    response = post(
        "auth/password/reset", {"email": verified_user.email, "code": code, "new_password": "new-river-stone-42"}
    )
    assert response.status_code == 200
    assert call("get", "me", old["access"]).status_code == 401  # все сессии отозваны
    assert post("auth/login", {"email": verified_user.email, "password": PASSWORD, "device": DEVICE}).status_code == 401
    assert login(verified_user, "new-river-stone-42")
    assert "изменён" in mailoutbox[-1].subject


def test_password_reset_unknown_email_same_response(post, mailoutbox):
    assert post("auth/password/forgot", {"email": "ghost@example.org"}).status_code == 202
    assert mailoutbox == []


def test_password_reset_wrong_code(post, verified_user, mailoutbox):
    post("auth/password/forgot", {"email": verified_user.email})
    response = post(
        "auth/password/reset", {"email": verified_user.email, "code": "000000", "new_password": "new-river-stone-42"}
    )
    assert response.status_code == 400
    verified_user.refresh_from_db()
    assert verified_user.check_password(PASSWORD)


def test_password_change_keeps_current_session_only(call, verified_user, login, session_for):
    current = login(verified_user)
    other = session_for(verified_user)
    wrong = call(
        "post",
        "auth/password/change",
        current["access"],
        {"old_password": "nope-nope-nope", "new_password": "new-river-stone-42"},
    )
    assert wrong.status_code == 400
    assert "old_password" in wrong.json()["error"]["fields"]

    ok = call(
        "post",
        "auth/password/change",
        current["access"],
        {"old_password": PASSWORD, "new_password": "new-river-stone-42"},
    )
    assert ok.status_code == 200
    assert call("get", "me", current["access"]).status_code == 200
    assert call("get", "me", other["access"]).status_code == 401


# --- Профиль ----------------------------------------------------------------------------------


def test_update_profile(call, verified_user, make_user, login):
    make_user(display_name="taken")
    access = login(verified_user)["access"]
    response = call("patch", "me", access, {"display_name": "new_name", "first_name": "Анна", "email": "x@y.z"})
    assert response.status_code == 200
    assert response.json()["display_name"] == "new_name"
    assert response.json()["email"] == verified_user.email  # email так не меняется
    assert call("patch", "me", access, {"display_name": "TAKEN"}).status_code == 400


def test_consents_listed(call, post, mailoutbox):
    register(post)
    tokens = post(
        "auth/verify-email", {"email": "new@example.org", "code": code_from(mailoutbox[0]), "device": DEVICE}
    ).json()
    documents = {c["document"] for c in call("get", "me/consents", tokens["access"]).json()}
    assert documents == set(settings.LEGAL_DOCUMENT_VERSIONS)


# --- 4.7 Удаление и выгрузка -----------------------------------------------------------------


def test_account_deletion_anonymizes(post, call, verified_user, login, mailoutbox):
    Consent.objects.create(user=verified_user, document="pd_processing", document_version="1.0")
    tokens = login(verified_user)
    email = verified_user.email

    assert post("me/deletion-code", token=tokens["access"]).status_code == 202
    assert call("post", "me/delete", tokens["access"], {"code": "000000"}).status_code == 400
    response = call("post", "me/delete", tokens["access"], {"code": code_from(mailoutbox[-1])})
    assert response.status_code == 204

    user = User.objects.get(pk=verified_user.pk)
    assert user.email == f"deleted+{user.pk}@invalid"
    assert user.display_name.startswith("deleted_")
    assert not user.is_active and user.deleted_at and not user.has_usable_password()
    assert not UserSession.objects.filter(user=user).exists()
    assert not user.consents.filter(withdrawn_at__isnull=True).exists()
    assert DataSubjectRequest.objects.filter(user=user, kind="delete", status="completed").exists()
    assert call("get", "me", tokens["access"]).status_code == 401
    assert post("auth/login", {"email": email, "password": PASSWORD, "device": DEVICE}).status_code == 401
    assert mailoutbox[-1].to == [email]
    # Email освободился — можно зарегистрироваться заново.
    assert register(post, email=email, display_name="reborn").status_code == 202
    assert User.objects.filter(email=email, display_name="reborn").exists()


def test_data_export_sent_once_a_day(post, verified_user, login, mailoutbox):
    access = login(verified_user)["access"]
    assert post("me/export", token=access).status_code == 202
    _name, content, mimetype = mailoutbox[-1].attachments[0]
    data = json.loads(content)
    assert mimetype == "application/json"
    assert data["profile"]["email"] == verified_user.email
    assert "password" not in content and "refresh" not in content
    assert DataSubjectRequest.objects.filter(user=verified_user, kind="export").exists()
    assert post("me/export", token=access).status_code == 429


def test_cleanup_anonymizes_stale_unverified(make_user):
    stale = make_user(created_at=timezone.now() - timedelta(days=8))
    fresh = make_user()
    verified = make_user(created_at=timezone.now() - timedelta(days=30), email_verified_at=timezone.now())
    assert services.cleanup_expired() == 1
    stale.refresh_from_db()
    assert stale.deleted_at is not None
    assert User.objects.get(pk=fresh.pk).deleted_at is None
    assert User.objects.get(pk=verified.pk).deleted_at is None


# --- 4.10 Журнал безопасности ----------------------------------------------------------------


def test_security_log_has_no_secrets(post, mailoutbox):
    register(post)
    code = code_from(mailoutbox[0])
    post("auth/verify-email", {"email": "new@example.org", "code": code, "device": DEVICE})
    dump = json.dumps(list(SecurityEvent.objects.values("event", "details")), default=str)
    assert code not in dump and "glass-river-1987" not in dump
    assert {"auth.register", "auth.verify_email"} <= set(SecurityEvent.objects.values_list("event", flat=True))
