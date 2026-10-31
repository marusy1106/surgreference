from datetime import timedelta

import pytest
from django.test import override_settings

from apps.assessment.tests.helpers import run_quiz
from apps.content.models import Lesson
from apps.gamification import clock, services
from apps.gamification.models import UserAchievement, UserStats, XpReason

pytestmark = [pytest.mark.django_db, pytest.mark.usefixtures("demo_content")]


def complete_lesson(client):
    return client.post(f"/api/v1/lessons/{Lesson.objects.get(slug='diagnosis').pk}/complete")


def test_overview_for_a_new_user(learner, as_user):
    body = as_user(learner).get("/api/v1/me/progress").json()

    assert body["level"] == 1
    assert body["total_xp"] == 0
    assert body["next_level_xp"] == 100
    assert body["current_streak"] == 0
    assert body["continue_lesson"]["title"].startswith("Острый аппендицит")
    assert body["last_quiz"] is None
    assert body["weak_topic"] is None


def test_overview_after_learning(learner, as_user, human_speed):
    client = as_user(learner)
    complete_lesson(client)
    run_quiz(client, right=2)

    body = client.get("/api/v1/me/progress").json()

    # урок 20 + 2 верных × 2 + достижения «первый урок» 5 и «первый тест» 5
    assert body["total_xp"] == 34
    assert body["week_xp"] == 34
    assert body["current_streak"] == 1
    assert body["lessons_completed"] == 1
    assert body["quizzes_finished"] == 1
    assert body["last_quiz"] == {
        "quiz_id": body["last_quiz"]["quiz_id"],
        "topic": "Острый аппендицит",
        "correct": 2,
        "total": 5,
        "palette_token": "surgery",
    }
    assert body["weak_topic"]["title"] == "Острый аппендицит"
    assert body["continue_lesson"] is None, "the only lesson is done"
    codes = set(UserAchievement.objects.filter(user=learner).values_list("achievement__code", flat=True))
    assert codes == {"first_lesson", "first_quiz"}


def test_streak_grows_on_consecutive_days_and_pays_from_day_two(learner):
    UserStats.objects.create(
        user=learner, current_streak=3, longest_streak=3, last_active_date=clock.today() - timedelta(days=1)
    )

    services.record_activity(learner)
    services.record_activity(learner)  # второй раз за день ничего не меняет

    stats = UserStats.objects.get(user=learner)
    assert stats.current_streak == 4
    assert learner.xp_events.filter(reason=XpReason.STREAK).get().amount == 5


def test_streak_resets_after_a_missed_day(learner, as_user):
    UserStats.objects.create(
        user=learner, current_streak=5, longest_streak=5, last_active_date=clock.today() - timedelta(days=2)
    )
    assert as_user(learner).get("/api/v1/me/progress").json()["current_streak"] == 0

    services.record_activity(learner)

    stats = UserStats.objects.get(user=learner)
    assert (stats.current_streak, stats.longest_streak) == (1, 5)
    assert not learner.xp_events.filter(reason=XpReason.STREAK).exists()


@override_settings(XP_DAILY_CAP=25)
def test_daily_cap_limits_xp_but_keeps_progress(learner, as_user, human_speed):
    client = as_user(learner)
    complete_lesson(client)  # 20 + 5 за достижение = 25 — лимит исчерпан
    _, result = run_quiz(client, right=5)

    assert result["xp_awarded"] == 0
    assert UserStats.objects.get(user=learner).total_xp == 25
    assert UserStats.objects.get(user=learner).quizzes_finished == 1


def test_award_is_idempotent(learner):
    args = {"source_type": "test", "source_id": 1, "key": "test:1"}
    assert services.award_xp(learner, 10, XpReason.QUIZ_CORRECT, **args) == 10
    assert services.award_xp(learner, 10, XpReason.QUIZ_CORRECT, **args) == 0
    assert UserStats.objects.get(user=learner).total_xp == 10


def test_level_follows_total_xp(learner):
    services.award_xp(learner, 300, XpReason.QUIZ_CORRECT, source_type="t", source_id=1, key="t:1")
    assert UserStats.objects.get(user=learner).level == 3


def test_activity_has_a_bucket_per_period(learner, as_user):
    services.award_xp(learner, 7, XpReason.QUIZ_CORRECT, source_type="t", source_id=1, key="t:1")
    client = as_user(learner)

    week = client.get("/api/v1/me/activity?period=week").json()["points"]
    month = client.get("/api/v1/me/activity?period=month").json()["points"]
    year = client.get("/api/v1/me/activity?period=year").json()["points"]

    assert (len(week), len(month), len(year)) == (7, 30, 12)
    assert week[-1]["xp"] == 7
    assert sum(p["xp"] for p in year) == 7
    assert client.get("/api/v1/me/activity?period=decade").status_code == 400


def test_achievements_list_marks_earned(learner, as_user):
    complete_lesson(as_user(learner))

    body = as_user(learner).get("/api/v1/me/achievements").json()

    earned = [a["code"] for a in body if a["earned_at"]]
    assert earned == ["first_lesson"]
    assert len(body) >= 10
