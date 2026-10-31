import json

import pytest

from apps.assessment.tests.helpers import correct_ids, run_quiz, wrong_id
from apps.gamification.models import UserAchievement, UserStats

pytestmark = [pytest.mark.django_db, pytest.mark.usefixtures("demo_content")]


def finish_practice(client, started, *, right=None):
    """Ответить на все вопросы попытки (верно — если id вопроса в `right`, по умолчанию все) и завершить."""
    for question in started["questions"]:
        ok = right is None or question["id"] in right
        ids = correct_ids(question["id"]) if ok else [wrong_id(question["id"])]
        response = client.post(
            f"/api/v1/attempts/{started['attempt_id']}/answers",
            {"question_id": question["id"], "option_ids": ids},
            format="json",
        )
        assert response.status_code == 204, response.json()
    return client.post(f"/api/v1/attempts/{started['attempt_id']}/finish").json()


def surgery(client):
    return next(d for d in client.get("/api/v1/practice").json() if d["slug"] == "surgery")


def test_practice_lists_only_disciplines_with_questions(learner, as_user):
    body = as_user(learner).get("/api/v1/practice").json()

    assert [d["slug"] for d in body] == ["surgery"]
    assert body[0] == {
        "slug": "surgery",
        "title": "Хирургия",
        "palette_token": "surgery",
        "questions": 5,
        "mistakes": 0,
        "mistakes_available": False,
    }


def test_training_starts_without_quiz_and_hides_answers(learner, as_user):
    response = as_user(learner).post("/api/v1/disciplines/surgery/training")

    assert response.status_code == 201
    body = response.json()
    assert body["quiz"]["id"] is None
    assert body["quiz"]["mode"] == "training"
    assert body["quiz"]["title"] == "Тренировка · Хирургия"
    assert len(body["questions"]) == 5
    assert "is_correct" not in json.dumps(body)


def test_training_awards_xp_only_for_first_correct_answers(learner, as_user, human_speed):
    client = as_user(learner)
    started, _ = run_quiz(client, right=3)
    known = {q["id"] for q in started["questions"][:3]}

    first = finish_practice(client, client.post("/api/v1/disciplines/surgery/training").json())
    again = finish_practice(client, client.post("/api/v1/disciplines/surgery/training").json())

    # Два вопроса, на которые раньше был неверный ответ, × 2 XP; бонуса за ≥ 80 % у тренировки нет.
    assert first["correct"] == 5
    assert first["xp_awarded"] == 2 * (5 - len(known))
    assert again["xp_awarded"] == 0


def test_flagged_training_gets_no_xp(learner, as_user):
    client = as_user(learner)
    result = finish_practice(client, client.post("/api/v1/disciplines/surgery/training").json())

    assert result["correct"] == 5
    assert result["xp_awarded"] == 0


def test_mistakes_locked_until_five_errors(learner, as_user, human_speed):
    client = as_user(learner)
    run_quiz(client, right=1)

    response = client.post("/api/v1/disciplines/surgery/mistakes")

    assert response.status_code == 400
    assert "сейчас их 4" in json.dumps(response.json(), ensure_ascii=False)
    assert surgery(client)["mistakes"] == 4


def test_mistakes_session_clears_fixed_questions(learner, as_user, human_speed):
    client = as_user(learner)
    run_quiz(client, right=0)
    assert surgery(client)["mistakes_available"] is True

    started = client.post("/api/v1/disciplines/surgery/mistakes").json()
    assert started["quiz"]["mode"] == "mistakes"
    assert len(started["questions"]) == 5
    fixed = {q["id"] for q in started["questions"][:2]}
    result = finish_practice(client, started, right=fixed)

    assert result["xp_awarded"] == 2 * len(fixed)
    assert surgery(client)["mistakes"] == 3
    assert UserStats.objects.get(user=learner).mistakes_finished == 1
    review = client.get(f"/api/v1/attempts/{started['attempt_id']}/review").json()
    assert review["lesson_id"] is None
    assert review["quiz"]["title"] == "Работа над ошибками · Хирургия"


def test_fifth_mistakes_session_unlocks_achievement(learner, as_user, human_speed):
    client = as_user(learner)
    run_quiz(client, right=0)
    UserStats.objects.filter(user=learner).update(mistakes_finished=4)

    finish_practice(client, client.post("/api/v1/disciplines/surgery/mistakes").json(), right=set())

    assert UserAchievement.objects.filter(user=learner, achievement__code="mistakes_5").exists()


def test_new_practice_attempt_abandons_previous(learner, as_user):
    client = as_user(learner)
    first = client.post("/api/v1/disciplines/surgery/training").json()
    client.post("/api/v1/disciplines/surgery/training")

    response = client.post(f"/api/v1/attempts/{first['attempt_id']}/finish")

    assert response.status_code == 400


def test_unknown_discipline(learner, as_user):
    assert as_user(learner).post("/api/v1/disciplines/nope/training").status_code == 404


def test_practice_requires_auth(api_client):
    assert api_client.get("/api/v1/practice").status_code == 401
