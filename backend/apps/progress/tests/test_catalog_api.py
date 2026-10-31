import pytest

from apps.assessment.tests.helpers import run_quiz
from apps.content.models import CatalogStatus, Discipline, Lesson
from apps.progress.models import TopicMastery

pytestmark = [pytest.mark.django_db, pytest.mark.usefixtures("demo_content")]


def test_catalog_lists_published_disciplines(learner, as_user):
    Discipline.objects.filter(slug="neurology").update(status=CatalogStatus.DRAFT)

    body = as_user(learner).get("/api/v1/disciplines").json()

    slugs = [d["slug"] for d in body]
    assert "surgery" in slugs
    assert "neurology" not in slugs
    surgery = next(d for d in body if d["slug"] == "surgery")
    assert surgery == {
        "slug": "surgery",
        "title": "Хирургия",
        "palette_token": "surgery",
        "is_premium": False,
        "topics_count": 3,
        "mastery": 0.0,
    }


def test_discipline_detail_has_lessons_quiz_and_empty_topics(learner, as_user):
    body = as_user(learner).get("/api/v1/disciplines/surgery").json()

    appendicitis, cholecystitis, _ = body["topics"]
    assert appendicitis["quiz"]["questions"] == 5
    assert appendicitis["lessons"][0]["completed"] is False
    assert cholecystitis["lessons"] == []
    assert cholecystitis["quiz"] is None
    assert as_user(learner).get("/api/v1/disciplines/unknown").status_code == 404


def test_lesson_shows_body_sources_and_reviewer(learner, as_user):
    lesson = Lesson.objects.get(slug="diagnosis")

    body = as_user(learner).get(f"/api/v1/lessons/{lesson.pk}").json()

    assert body["title"].startswith("Острый аппендицит")
    assert {b["type"] for b in body["body"]} >= {"paragraph", "heading", "list", "callout", "table"}
    assert body["reviewer"] == "демо-рецензент"
    assert "Острый аппендицит у взрослых" in body["sources"][0]


def test_unpublished_lesson_is_not_found(learner, as_user):
    lesson = Lesson.objects.get(slug="diagnosis")
    lesson.published_revision = None
    lesson.save()

    assert as_user(learner).get(f"/api/v1/lessons/{lesson.pk}").status_code == 404


def test_lesson_completion_awards_xp_once(learner, as_user):
    client = as_user(learner)
    lesson = Lesson.objects.get(slug="diagnosis")

    first = client.post(f"/api/v1/lessons/{lesson.pk}/complete").json()
    second = client.post(f"/api/v1/lessons/{lesson.pk}/complete").json()

    assert first["first_time"] is True
    assert second["first_time"] is False
    assert learner.xp_events.filter(reason="lesson_completed").get().amount == 20
    detail = client.get("/api/v1/disciplines/surgery").json()
    assert detail["topics"][0]["lessons"][0]["completed"] is True


def test_quiz_updates_topic_and_discipline_mastery(learner, as_user, human_speed):
    client = as_user(learner)
    run_quiz(client, right=4)

    mastery = TopicMastery.objects.get(user=learner)
    assert mastery.answered == 5
    assert mastery.correct == 4
    assert float(mastery.mastery) == 0.8
    surgery = next(d for d in client.get("/api/v1/disciplines").json() if d["slug"] == "surgery")
    assert surgery["mastery"] == 0.8
    topic = client.get("/api/v1/disciplines/surgery").json()["topics"][0]
    assert topic["mastered"] is False, "needs at least 10 answers"
