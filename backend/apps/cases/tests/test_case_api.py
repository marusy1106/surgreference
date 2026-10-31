import json

import pytest

from apps.cases.models import CaseChoice, CaseChoiceQuality, ClinicalCase

pytestmark = [pytest.mark.django_db, pytest.mark.usefixtures("demo_content")]


def demo_case():
    return ClinicalCase.objects.get(title="Боль в правой подвздошной области")


def start(client):
    response = client.post(f"/api/v1/cases/{demo_case().pk}/attempts")
    assert response.status_code == 201
    return response.json()


def pick(step, quality):
    ids = [c["id"] for c in step["choices"]]
    return CaseChoice.objects.filter(pk__in=ids, quality=quality).values_list("pk", flat=True).first()


def test_list_and_start_hide_choice_quality(learner, as_user):
    client = as_user(learner)
    listed = client.get("/api/v1/cases").json()
    started = start(client)

    assert listed[0]["title"] == "Боль в правой подвздошной области"
    assert started["step"]["number"] == 1
    assert started["step_titles"] == ["Жалобы и анамнез", "Осмотр", "Обследование"]
    dumped = json.dumps(started, ensure_ascii=False)
    assert "optimal" not in dumped
    assert "feedback" not in dumped


def test_optimal_path_scores_full_and_awards_30_xp(learner, as_user):
    client = as_user(learner)
    started = start(client)
    step, outcome = started["step"], None
    while step:
        outcome = client.post(
            f"/api/v1/case-attempts/{started['attempt_id']}/choices",
            {"choice_id": pick(step, CaseChoiceQuality.OPTIMAL)},
            format="json",
        ).json()
        assert outcome["is_good"] is True
        step = outcome["next_step"]

    assert outcome["finished"] is True
    assert outcome["score"] == 1.0
    assert outcome["xp_awarded"] == 30


def test_wrong_choices_get_feedback_and_review_shows_optimal(learner, as_user):
    client = as_user(learner)
    started = start(client)
    url = f"/api/v1/case-attempts/{started['attempt_id']}/choices"
    step = started["step"]
    first = client.post(url, {"choice_id": pick(step, CaseChoiceQuality.DANGEROUS)}, format="json").json()
    assert first["is_good"] is False
    assert first["feedback"].startswith("Картина типична")
    assert first["optimal_choice_id"] == pick(step, CaseChoiceQuality.OPTIMAL)

    step = first["next_step"]
    while step:
        step = client.post(url, {"choice_id": pick(step, CaseChoiceQuality.OPTIMAL)}, format="json").json()["next_step"]

    review = client.get(f"/api/v1/case-attempts/{started['attempt_id']}/review").json()
    assert len(review["steps"]) == 3
    assert review["steps"][0]["chosen"]["is_good"] is False
    assert review["steps"][0]["optimal"]["text"] == "Осмотр живота и измерение температуры"
    assert review["score"] == pytest.approx(2 / 6, abs=0.01), "dangerous choice costs points"
    assert review["debrief"].startswith("Оптимальный путь")
    assert "вымышлен" in review["disclaimer"]


def test_choice_from_another_step_is_rejected(learner, as_user):
    client = as_user(learner)
    started = start(client)
    later_step_choice = CaseChoice.objects.filter(step__case=demo_case(), step__sort_order=2).first()

    response = client.post(
        f"/api/v1/case-attempts/{started['attempt_id']}/choices", {"choice_id": later_step_choice.pk}, format="json"
    )

    assert response.status_code == 400


def test_repeat_case_awards_only_improvement(learner, as_user):
    client = as_user(learner)

    def play(quality_first):
        started = start(client)
        step, outcome = started["step"], None
        quality = quality_first
        while step:
            outcome = client.post(
                f"/api/v1/case-attempts/{started['attempt_id']}/choices",
                {"choice_id": pick(step, quality)},
                format="json",
            ).json()
            step, quality = outcome["next_step"], CaseChoiceQuality.OPTIMAL
        return outcome

    assert play(CaseChoiceQuality.WRONG)["xp_awarded"] == 20  # 30 × 4/6
    assert play(CaseChoiceQuality.OPTIMAL)["xp_awarded"] == 10
    assert play(CaseChoiceQuality.OPTIMAL)["xp_awarded"] == 0


def test_foreign_attempt_is_not_found(learner, make_user, as_user):
    started = start(as_user(learner))
    intruder = as_user(make_user())

    url = f"/api/v1/case-attempts/{started['attempt_id']}"
    assert intruder.post(f"{url}/choices", {"choice_id": 1}, format="json").status_code == 404
    assert intruder.get(f"{url}/review").status_code == 404
