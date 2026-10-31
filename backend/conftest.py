import itertools

import pytest
from django.core.cache import cache
from rest_framework.test import APIClient

_seq = itertools.count(1)


@pytest.fixture(autouse=True)
def _clear_cache():
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def make_user(db, django_user_model):
    def factory(**kwargs):
        n = next(_seq)
        kwargs.setdefault("email", f"user{n}@example.org")
        kwargs.setdefault("display_name", f"user{n}")
        password = kwargs.pop("password", "correct-horse-battery")
        return django_user_model.objects.create_user(password=password, **kwargs)

    return factory


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def demo_content(db):
    """Опубликованный демо-контент: хирургия → «Острый аппендицит» (урок, тест из 5 вопросов) и кейс."""
    from django.core.management import call_command

    call_command("seed_demo_content", force=True, stdout=open("/dev/null", "w"))


@pytest.fixture
def learner(make_user):
    from django.utils import timezone

    return make_user(email_verified_at=timezone.now())


@pytest.fixture
def as_user():
    """Клиент API от имени пользователя (без выпуска токенов — их проверяют тесты accounts)."""

    def _client(user):
        client = APIClient()
        client.force_authenticate(user)
        return client

    return _client


@pytest.fixture
def human_speed(monkeypatch):
    """Тесты отвечают мгновенно; отключаем порог «похоже на автоматизацию», где он не проверяется."""
    monkeypatch.setattr("apps.assessment.services.SUSPICIOUS_AVG_ANSWER_MS", 0)
