import json

import pytest

from apps.accounts import services
from apps.universities.models import EducationProfile, EducationProfileHistory, EducationStatus

pytestmark = pytest.mark.django_db


def test_education_profile_removed_on_anonymize(make_user):
    user = make_user()
    EducationProfile.objects.create(user=user, status=EducationStatus.STUDENT, course=3)
    EducationProfileHistory.objects.create(user=user, snapshot={"status": "student"})
    services.anonymize(user, note="тест")
    assert not EducationProfile.objects.filter(user=user).exists()
    assert not EducationProfileHistory.objects.filter(user=user).exists()


def test_education_included_in_export(make_user):
    user = make_user()
    EducationProfile.objects.create(user=user, status=EducationStatus.DOCTOR)
    data = json.loads(json.dumps(services.build_export(user), default=str))
    assert data["education"]["current"]["status"] == "doctor"


def test_export_without_education(make_user):
    assert "education" not in services.build_export(make_user())
