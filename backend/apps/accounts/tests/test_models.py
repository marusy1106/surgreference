import pytest
from django.contrib.auth.hashers import check_password, make_password
from django.db import IntegrityError
from django.test import override_settings

pytestmark = pytest.mark.django_db


def test_email_is_normalized_to_lowercase(make_user):
    user = make_user(email="  Ivan.Petrov@Example.ORG ")
    assert user.email == "ivan.petrov@example.org"


def test_email_unique_regardless_of_case(make_user):
    make_user(email="a@example.org")
    with pytest.raises(IntegrityError):
        make_user(email="A@EXAMPLE.org")


def test_uppercase_email_rejected_by_db(make_user, django_user_model):
    user = make_user()
    with pytest.raises(IntegrityError):
        django_user_model.objects.filter(pk=user.pk).update(email="Upper@example.org")


def test_display_name_unique_case_insensitive(make_user):
    make_user(display_name="Surgeon")
    with pytest.raises(IntegrityError):
        make_user(display_name="surgeon")


def test_new_user_is_not_verified_and_not_in_leaderboard(make_user):
    user = make_user()
    assert not user.is_verified
    assert user.leaderboard_opt_in is False
    assert user.trust_status == "ok"


def test_superuser_is_verified(django_user_model, db):
    admin = django_user_model.objects.create_superuser(
        email="admin@example.org", display_name="admin", password="very-long-password"
    )
    assert admin.is_staff and admin.is_superuser and admin.is_verified


@override_settings(PASSWORD_HASHERS=["apps.accounts.hashers.TunedArgon2PasswordHasher"])
def test_production_hasher_is_argon2id():
    encoded = make_password("correct-horse-battery")
    assert encoded.startswith("argon2$argon2id$")
    assert "m=65536,t=3,p=2" in encoded
    assert check_password("correct-horse-battery", encoded)
