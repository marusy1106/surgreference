import pytest
from django.db import IntegrityError
from django.utils import timezone

from apps.cases.models import ClinicalCase
from apps.content.models import Discipline, ReviewStatus

pytestmark = pytest.mark.django_db


@pytest.fixture
def discipline():
    return Discipline.objects.create(slug="surgery", title="Хирургия")


def test_case_cannot_be_non_synthetic(discipline, make_user):
    with pytest.raises(IntegrityError):
        ClinicalCase.objects.create(discipline=discipline, title="Кейс", author=make_user(), is_synthetic=False)


def test_publish_requires_synthetic_attestation(discipline, make_user):
    with pytest.raises(IntegrityError):
        ClinicalCase.objects.create(
            discipline=discipline,
            title="Кейс",
            author=make_user(),
            reviewer=make_user(),
            status=ReviewStatus.PUBLISHED,
            published_at=timezone.now(),
        )


def test_attested_case_can_be_published(discipline, make_user):
    reviewer = make_user()
    case = ClinicalCase.objects.create(
        discipline=discipline,
        title="Пациент М., 54 года, боль в правой подвздошной области",
        author=make_user(),
        reviewer=reviewer,
        synthetic_attested_by=reviewer,
        status=ReviewStatus.PUBLISHED,
        published_at=timezone.now(),
    )
    assert case.is_synthetic
