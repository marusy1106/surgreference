import json
from datetime import timedelta

import pytest
from django.utils import timezone

from apps.assessment import services
from apps.assessment.models import QuizAttempt, QuizAttemptStatus

from .helpers import correct_ids, demo_quiz, run_quiz, wrong_id

pytestmark = [pytest.mark.django_db, pytest.mark.usefixtures("demo_content")]


def test_start_hides_correct_answers(learner, as_user):
    response = as_user(learner).post(f"/api/v1/quizzes/{demo_quiz().pk}/attempts")

    assert response.status_code == 201
    body = response.json()
    assert len(body["questions"]) == 5
    assert body["quiz"]["palette_token"] == "surgery"
    dumped = json.dumps(body, ensure_ascii=False)
    assert "is_correct" not in dumped
    assert "explanation" not in dumped
    assert "Кохер (Кохер" not in dumped, "option explanations must not leak before finish"


def test_answer_validation(learner, as_user):
    client = as_user(learner)
    started = client.post(f"/api/v1/quizzes/{demo_quiz().pk}/attempts").json()
    single = started["questions"][0]
    url = f"/api/v1/attempts/{started['attempt_id']}/answers"
    other_question = started["questions"][1]["id"]

    two = [o["id"] for o in single["options"][:2]]
    assert client.post(url, {"question_id": single["id"], "option_ids": two}, format="json").status_code == 400
    foreign = {"question_id": single["id"], "option_ids": [wrong_id(other_question)]}
    assert client.post(url, foreign, format="json").status_code == 400
    assert client.post(url, {"question_id": 999999, "option_ids": [1]}, format="json").status_code == 400


def test_first_attempt_scores_and_awards_xp(learner, as_user, human_speed):
    _, result = run_quiz(as_user(learner), right=4)

    assert result["correct"] == 4
    assert result["total"] == 5
    # 4 верных × 2 XP + 10 XP бонус за ≥ 80 %
    assert result["xp_awarded"] == 18


def test_review_explains_every_option(learner, as_user, human_speed):
    client = as_user(learner)
    started, _ = run_quiz(client, right=0)

    review = client.get(f"/api/v1/attempts/{started['attempt_id']}/review").json()

    assert review["lesson_id"] is not None
    first = review["items"][0]
    assert first["is_correct"] is False
    assert all(o["explanation"] for o in first["options"])
    assert sum(o["selected"] for o in first["options"]) == 1
    assert {o["id"] for o in first["options"] if o["is_correct"]} == set(correct_ids(first["question_id"]))


def test_repeat_attempt_awards_only_improvement(learner, as_user, human_speed):
    client = as_user(learner)
    run_quiz(client, right=2)
    _, same = run_quiz(client, right=2)
    _, better = run_quiz(client, right=5)

    assert same["xp_awarded"] == 0
    # (5 − 2) × 2 XP + бонус за ≥ 80 % впервые
    assert better["xp_awarded"] == 16
    _, again = run_quiz(client, right=5)
    assert again["xp_awarded"] == 0, "bonus is paid once per quiz"


def test_finish_is_idempotent(learner, as_user, human_speed):
    client = as_user(learner)
    started, first = run_quiz(client, right=3)

    second = client.post(f"/api/v1/attempts/{started['attempt_id']}/finish").json()

    assert second == first
    assert learner.xp_events.filter(reason="quiz_correct").count() == 1


def test_review_is_closed_before_finish(learner, as_user):
    client = as_user(learner)
    started = client.post(f"/api/v1/quizzes/{demo_quiz().pk}/attempts").json()

    assert client.get(f"/api/v1/attempts/{started['attempt_id']}/review").status_code == 404


def test_foreign_attempt_is_not_found(learner, make_user, as_user):
    started = as_user(learner).post(f"/api/v1/quizzes/{demo_quiz().pk}/attempts").json()
    intruder = as_user(make_user())
    base = f"/api/v1/attempts/{started['attempt_id']}"

    assert intruder.post(f"{base}/answers", {"question_id": 1, "option_ids": [1]}, format="json").status_code == 404
    assert intruder.post(f"{base}/finish").status_code == 404
    assert intruder.get(f"{base}/review").status_code == 404


def test_too_fast_answers_are_flagged_and_earn_no_xp(learner, as_user):
    _, result = run_quiz(as_user(learner), right=5)

    attempt = QuizAttempt.objects.get(pk=result["attempt_id"])
    assert attempt.flagged is True
    assert result["xp_awarded"] == 0


def test_new_attempt_abandons_previous_and_old_ones_expire(learner, as_user):
    client = as_user(learner)
    first = client.post(f"/api/v1/quizzes/{demo_quiz().pk}/attempts").json()
    second = client.post(f"/api/v1/quizzes/{demo_quiz().pk}/attempts").json()

    assert QuizAttempt.objects.get(pk=first["attempt_id"]).status == QuizAttemptStatus.ABANDONED
    QuizAttempt.objects.filter(pk=second["attempt_id"]).update(started_at=timezone.now() - timedelta(hours=25))
    assert services.expire_attempts() == 1
    assert client.post(f"/api/v1/attempts/{second['attempt_id']}/finish").status_code == 400


def test_requires_authentication(api_client, demo_content):
    assert api_client.post(f"/api/v1/quizzes/{demo_quiz().pk}/attempts").status_code == 401
