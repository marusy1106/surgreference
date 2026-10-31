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
