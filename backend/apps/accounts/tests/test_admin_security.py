"""Админка: обязательный второй фактор, роли, журналы (docs/04, 4.5, 4.10)."""

import io

import pytest
from django.contrib.admin.models import CHANGE, LogEntry
from django.contrib.auth.models import Group
from django.contrib.contenttypes.models import ContentType
from django.core.management import call_command
from django_otp.oath import totp
from django_otp.plugins.otp_static.models import StaticDevice
from django_otp.plugins.otp_totp.models import TOTPDevice

from apps.accounts.models import User
from apps.accounts.roles import ROLES
from apps.audit.models import AdminAuditLog, SecurityEvent

pytestmark = pytest.mark.django_db
PASSWORD = "correct-horse-battery"


@pytest.fixture
def staff(make_user):
    return make_user(email="editor@example.org", display_name="editor", is_staff=True)


@pytest.fixture
def superadmin(make_user):
    return make_user(email="root@example.org", display_name="root", is_staff=True, is_superuser=True)


def enroll(user):
    call_command("enroll_totp", user.email, stdout=io.StringIO())
    return TOTPDevice.objects.get(user=user)


def admin_login(client, user, token="", device=None):
    data = {"username": user.email, "password": PASSWORD, "otp_token": token}
    if device is not None:
        data["otp_device"] = device.persistent_id
    return client.post("/admin/login/?next=/admin/", data)


def test_admin_closed_without_second_factor(client, staff):
    response = admin_login(client, staff)
    assert response.status_code == 200  # остаёмся на форме входа
    assert client.get("/admin/").status_code == 302


def test_admin_open_with_totp(client, staff):
    device = enroll(staff)
    response = admin_login(client, staff, totp(device.bin_key), device)
    assert response.status_code == 302
    assert client.get("/admin/").status_code == 200
    assert SecurityEvent.objects.filter(event="admin.login", outcome="success", actor=staff).exists()


def test_admin_wrong_totp_logged(client, staff):
    device = enroll(staff)
    response = admin_login(client, staff, "000000", device)
    assert response.status_code == 200
    assert client.get("/admin/").status_code == 302
    assert SecurityEvent.objects.filter(event="admin.mfa", outcome="failure", subject=staff).exists()


def test_admin_backup_code_is_single_use(client, staff):
    enroll(staff)
    static = StaticDevice.objects.get(user=staff)
    code = static.token_set.first().token
    assert admin_login(client, staff, code, static).status_code == 302
    client.logout()
    assert admin_login(client, staff, code, static).status_code == 200


def test_enroll_requires_reset_to_replace(staff):
    enroll(staff)
    with pytest.raises(Exception, match="--reset"):
        call_command("enroll_totp", staff.email, stdout=io.StringIO())
    out = io.StringIO()
    call_command("enroll_totp", staff.email, "--reset", stdout=out)
    assert "otpauth://totp/" in out.getvalue()
    assert TOTPDevice.objects.filter(user=staff).count() == 1


def test_enroll_only_for_staff(make_user):
    user = make_user()
    with pytest.raises(Exception, match="не найден"):
        call_command("enroll_totp", user.email, stdout=io.StringIO())


def test_roles_synced_with_least_privilege():
    assert set(Group.objects.values_list("name", flat=True)) >= set(ROLES)
    analyst = set(Group.objects.get(name="analyst").permissions.values_list("codename", flat=True))
    assert "view_user" not in analyst  # аналитик не видит email пользователей
    assert "view_dailymetrics" in analyst
    author = set(Group.objects.get(name="content_author").permissions.values_list("codename", flat=True))
    assert "change_lesson" in author and "delete_lesson" not in author
    assert not any(p.endswith("_securityevent") for p in author | analyst)


def logged_in(client, user):
    device = enroll(user)
    admin_login(client, user, totp(device.bin_key), device)
    return client


def test_only_superadmin_changes_roles(client, staff, make_user, superadmin, mailoutbox):
    support = Group.objects.get(name="support")
    staff.groups.add(support)
    target = make_user(display_name="target")

    page = logged_in(client, staff).get(f"/admin/accounts/user/{target.pk}/change/")
    assert page.status_code == 200
    assert 'name="groups"' not in page.content.decode()

    client.logout()
    logged_in(client, superadmin)
    data = {
        "email": target.email,
        "display_name": target.display_name,
        "first_name": "",
        "is_active": "on",
        "is_staff": "on",
        "trust_status": "ok",
        "groups": [support.pk],
    }
    response = client.post(f"/admin/accounts/user/{target.pk}/change/", data)
    assert response.status_code == 302, response.content.decode()[:2000]
    target.refresh_from_db()
    assert target.is_staff and list(target.groups.all()) == [support]
    event = SecurityEvent.objects.get(event="admin.roles_changed")
    assert event.actor == superadmin and event.details["after"]["groups"] == ["support"]
    assert AdminAuditLog.objects.filter(staff_user=superadmin, action="change", model="accounts.User").exists()


def test_audit_logs_visible_only_to_superadmin(client, staff, superadmin):
    staff.groups.add(Group.objects.get(name="support"))
    assert logged_in(client, staff).get("/admin/audit/securityevent/").status_code == 403
    client.logout()
    assert logged_in(client, superadmin).get("/admin/audit/securityevent/").status_code == 200


def test_users_cannot_be_deleted_only_anonymized(client, superadmin, make_user):
    target = make_user()
    logged_in(client, superadmin)
    assert client.get(f"/admin/accounts/user/{target.pk}/delete/").status_code == 403
    response = client.post(
        "/admin/accounts/user/",
        {"action": "anonymize_users", "_selected_action": [target.pk]},
    )
    assert response.status_code == 302
    target.refresh_from_db()
    assert target.deleted_at is not None and not target.is_active


def test_admin_log_entry_copied_to_append_only_journal(staff):
    LogEntry.objects.log_actions(
        user_id=staff.pk,
        queryset=User.objects.filter(pk=staff.pk),
        action_flag=CHANGE,
        change_message="[]",
        single_object=True,
    )
    entry = AdminAuditLog.objects.get()
    assert entry.staff_user == staff and entry.model == "accounts.User" and entry.object_id == str(staff.pk)
    assert ContentType.objects.get_for_model(User)
