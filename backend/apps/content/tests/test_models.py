import pytest
from django.db import IntegrityError, transaction
from django.utils import timezone

from apps.content.models import Discipline, Lesson, LessonRevision, ReviewStatus, Topic

pytestmark = pytest.mark.django_db


@pytest.fixture
def lesson():
    discipline = Discipline.objects.create(slug="surgery", title="Хирургия")
    topic = Topic.objects.create(discipline=discipline, slug="appendicitis", title="Острый аппендицит")
    return Lesson.objects.create(topic=topic, slug="diagnosis")


def make_revision(lesson, author, version, **kwargs):
    return LessonRevision.objects.create(lesson=lesson, author=author, version=version, title="Диагностика", **kwargs)


def test_reviewer_cannot_be_author(lesson, make_user):
    author = make_user()
    with pytest.raises(IntegrityError):
        make_revision(lesson, author, 1, reviewer=author)


def test_approved_requires_reviewer(lesson, make_user):
    with pytest.raises(IntegrityError):
        make_revision(lesson, make_user(), 1, status=ReviewStatus.APPROVED)


def test_published_requires_date(lesson, make_user):
    with pytest.raises(IntegrityError):
        make_revision(lesson, make_user(), 1, status=ReviewStatus.PUBLISHED, reviewer=make_user())


def test_only_one_published_revision_per_lesson(lesson, make_user):
    author, reviewer = make_user(), make_user()
    published = {"status": ReviewStatus.PUBLISHED, "reviewer": reviewer, "published_at": timezone.now()}
    make_revision(lesson, author, 1, **published)
    with pytest.raises(IntegrityError), transaction.atomic():
        make_revision(lesson, author, 2, **published)
    # Черновик следующей версии допустим.
    make_revision(lesson, author, 2)


def test_version_unique_per_lesson(lesson, make_user):
    author = make_user()
    make_revision(lesson, author, 1)
    with pytest.raises(IntegrityError):
        make_revision(lesson, author, 1)
