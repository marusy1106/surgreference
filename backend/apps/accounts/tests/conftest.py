import itertools
import re

import pytest
from django.conf import settings

from apps.accounts import services

_ips = itertools.count(1)
PASSWORD = "correct-horse-battery"
DEVICE = {"platform": "ios", "device_name": "iPhone 15", "app_version": "1.0.0"}


def consents():
    return [{"document": doc, "version": ver} for doc, ver in settings.LEGAL_DOCUMENT_VERSIONS.items()]


def code_from(mail):
    return re.search(r"\b(\d{6})\b", mail.subject).group(1)


@pytest.fixture
def client_ip():
    """Новый IP на каждый вызов: чтобы лимиты по IP не мешали сценариям, где они не проверяются."""
    return lambda: f"10.0.{next(_ips) % 250}.{next(_ips) % 250 + 1}"


@pytest.fixture
def post(api_client, client_ip):
    def _post(url, data=None, *, ip=None, token=None):
        headers = {"REMOTE_ADDR": ip or client_ip()}
        if token:
            headers["HTTP_AUTHORIZATION"] = f"Bearer {token}"
        return api_client.post(f"/api/v1/{url}", data or {}, format="json", **headers)

    return _post


@pytest.fixture
def call(api_client):
    def _call(method, url, token, data=None):
        kwargs = {"HTTP_AUTHORIZATION": f"Bearer {token}"} if token else {}
        return getattr(api_client, method)(f"/api/v1/{url}", data, format="json", **kwargs)

    return _call


@pytest.fixture
def verified_user(make_user):
    from django.utils import timezone

    return make_user(email="doc@example.org", display_name="doctor", email_verified_at=timezone.now())


@pytest.fixture
def login(post):
    def _login(user, password=PASSWORD):
        response = post("auth/login", {"email": user.email, "password": password, "device": DEVICE})
        assert response.status_code == 200, response.json()
        return response.json()

    return _login


@pytest.fixture
def session_for(rf):
    def _session(user):
        return services.start_session(user, services.Device(platform="android"), "10.1.1.1")

    return _session
