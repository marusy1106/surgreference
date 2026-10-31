import pytest
from django.utils import timezone

from apps.gamification import services
from apps.gamification.models import XpReason
from apps.universities.models import EducationProfile, EducationStatus, University

pytestmark = pytest.mark.django_db


@pytest.fixture
def university(db):
    return University.objects.create(name="Демо-медуниверситет", city="Москва")


@pytest.fixture
def player(make_user):
    def _player(xp, *, opt_in=True, verified=True, university=None, name=None):
        kwargs = {"display_name": name} if name else {}
        user = make_user(leaderboard_opt_in=opt_in, email_verified_at=timezone.now() if verified else None, **kwargs)
        if university:
            EducationProfile.objects.create(user=user, status=EducationStatus.STUDENT, university=university, course=3)
        services.award_xp(user, xp, XpReason.QUIZ_CORRECT, source_type="t", source_id=user.pk, key=f"t:{user.pk}")
        return user

    return _player


def test_only_opted_in_verified_users_are_listed(player, as_user):
    me = player(50, name="me")
    player(90, name="leader")
    player(500, opt_in=False, name="hidden")
    player(400, verified=False, name="unverified")

    body = as_user(me).get("/api/v1/leaderboards/users?period=week").json()

    assert [r["display_name"] for r in body["rows"]] == ["leader", "me"]
    assert body["me"]["rank"] == 2
    assert body["me"]["is_me"] is True
    assert "email" not in str(body)


def test_opting_out_removes_user_instantly(player, as_user):
    me = player(50)
    client = as_user(me)

    assert client.put("/api/v1/me/leaderboard-participation", {"opt_in": False}, format="json").json() == {
        "opt_in": False
    }
    me.refresh_from_db()
    body = client.get("/api/v1/leaderboards/users").json()
    assert body["rows"] == []
    assert body["me"] is None
    assert body["opted_in"] is False


def test_my_university_scope(player, as_user, university):
    other = University.objects.create(name="Другой вуз", city="Казань")
    me = player(10, university=university, name="me")
    player(20, university=university, name="classmate")
    player(99, university=other, name="stranger")

    body = as_user(me).get("/api/v1/leaderboards/users?scope=university").json()

    assert [r["display_name"] for r in body["rows"]] == ["classmate", "me"]
    assert body["rows"][0]["university"] == "Демо-медуниверситет"


def test_university_scope_without_profile_asks_for_one(player, as_user):
    body = as_user(player(10)).get("/api/v1/leaderboards/users?scope=university").json()
    assert body["needs_university"] is True


def test_university_board_needs_five_active_participants(player, as_user, university):
    small = University.objects.create(name="Маленький вуз", city="Тверь")
    for xp in (10, 20, 30, 40, 50):
        player(xp, university=university)
    viewer = player(100, university=small)

    body = as_user(viewer).get("/api/v1/leaderboards/universities?period=week").json()

    assert body["rows"] == [{"rank": 1, "name": "Демо-медуниверситет", "score": 30.0, "participants": 5}]


def test_bad_period_is_rejected(player, as_user):
    assert as_user(player(1)).get("/api/v1/leaderboards/users?period=decade").status_code == 400
