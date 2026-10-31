import pytest
from django.contrib.contenttypes.models import ContentType

from apps.assessment.models import QuizQuestion
from apps.content import editorial
from apps.content.editorial import EditorialError
from apps.content.models import ContentSource, Discipline, ReviewStatus, Source

from .helpers import demo_quiz

pytestmark = [pytest.mark.django_db, pytest.mark.usefixtures("demo_content")]


@pytest.fixture
def question():
    return QuizQuestion.objects.filter(quiz=demo_quiz()).order_by("sort_order").first().question


@pytest.fixture
def people(staff):
    reviewer = staff("medical_reviewer")
    Discipline.objects.get(slug="surgery").reviewers.add(reviewer)
    return staff("content_author"), reviewer, staff("chief_editor")


def test_new_version_copies_options_and_problems_are_checked(question, people):
    author, _, _ = people
    draft = editorial.new_version(question, author)

    assert draft.version == question.version + 1
    assert draft.previous_version == question
    assert [o.text for o in draft.options.all()] == [o.text for o in question.options.all()]
    draft.options.update(is_correct=True)
    draft.options.filter(sort_order=0).update(explanation="")
    with pytest.raises(EditorialError) as error:
        editorial.submit(draft, author)
    assert "несколько правильных" in str(error.value)
    assert "объяснение" in str(error.value)
    assert "источник" in str(error.value)


def test_publishing_new_version_swaps_it_into_the_quiz(question, people, learner, as_user):
    author, reviewer, editor = people
    draft = editorial.new_version(question, author)
    ContentSource.objects.create(
        content_type=ContentType.objects.get_for_model(draft), object_id=draft.pk, source=Source.objects.first()
    )
    editorial.submit(draft, author)
    editorial.review(draft, reviewer, "approve")
    editorial.publish(draft, editor)

    question.refresh_from_db()
    assert question.status == ReviewStatus.ARCHIVED
    started = as_user(learner).post(f"/api/v1/quizzes/{demo_quiz().pk}/attempts").json()
    ids = [q["id"] for q in started["questions"]]
    assert draft.pk in ids
    assert question.pk not in ids
