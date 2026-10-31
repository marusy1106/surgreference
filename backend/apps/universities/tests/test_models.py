import pytest
from django.db import IntegrityError

from apps.universities.models import EducationProfile, EducationStatus, University

pytestmark = pytest.mark.django_db


@pytest.fixture
def university():
    return University.objects.create(name="Медицинский университет", city="Москва")


def test_student_profile_with_course(make_user, university):
    profile = EducationProfile.objects.create(
        user=make_user(), status=EducationStatus.STUDENT, university=university, course=3
    )
    assert profile.verification_status == "unverified"


def test_course_not_allowed_for_doctor(make_user):
    with pytest.raises(IntegrityError):
        EducationProfile.objects.create(user=make_user(), status=EducationStatus.DOCTOR, course=3)


def test_course_range_enforced(make_user):
    with pytest.raises(IntegrityError):
        EducationProfile.objects.create(user=make_user(), status=EducationStatus.STUDENT, course=7)


def test_unknown_status_rejected(make_user):
    with pytest.raises(IntegrityError):
        EducationProfile.objects.create(user=make_user(), status="professor")
