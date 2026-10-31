import pytest

from apps.universities.models import (
    EducationProfile,
    EducationProfileHistory,
    Faculty,
    Specialty,
    University,
    UniversityRequest,
)
from apps.universities.services import approve_request, resolve_request

pytestmark = pytest.mark.django_db


@pytest.fixture
def sechenov():
    return University.objects.get(short_name="Сеченовский университет")


@pytest.fixture
def general_medicine():
    return Specialty.objects.get(code="31.05.01")


def search(client, query):
    return [u["short_name"] for u in client.get("/api/v1/universities", {"search": query}).json()]


def test_search_by_alias_short_name_and_city(learner, as_user):
    client = as_user(learner)

    assert search(client, "первый мед москва") == ["Сеченовский университет"]
    assert search(client, "ПМГМУ") == ["Сеченовский университет"]
    assert search(client, "пирогова") == ["РНИМУ им. Пирогова"]
    assert search(client, "огарева") == ["МГУ им. Огарёва"], "ё and е are the same"
    assert set(search(client, "КГМУ")) >= {"КГМУ"}
    assert len(client.get("/api/v1/universities").json()) == 20


def test_inactive_university_hidden(learner, as_user, sechenov):
    sechenov.is_active = False
    sechenov.save()

    assert search(as_user(learner), "сеченов") == []


def test_specialties_by_level(learner, as_user):
    body = as_user(learner).get("/api/v1/specialties", {"level": "specialitet"}).json()

    assert ("31.05.01", "Лечебное дело") in [(s["code"], s["name"]) for s in body]
    assert all(s["level"] == "specialitet" for s in body)


def test_faculties(learner, as_user, sechenov):
    Faculty.objects.create(university=sechenov, name="Институт клинической медицины")

    body = as_user(learner).get(f"/api/v1/universities/{sechenov.pk}/faculties").json()

    assert [f["name"] for f in body] == ["Институт клинической медицины"]


def test_empty_profile(learner, as_user):
    body = as_user(learner).get("/api/v1/me/education").json()

    assert body["status"] is None
    assert body["university"] is None


def test_save_student_profile(learner, as_user, sechenov, general_medicine):
    client = as_user(learner)
    data = {"status": "student", "university_id": sechenov.pk, "specialty_id": general_medicine.pk, "course": 5}

    body = client.put("/api/v1/me/education", data, format="json").json()

    assert body["status"] == "student"
    assert body["university"]["short_name"] == "Сеченовский университет"
    assert body["specialty"]["name"] == "Лечебное дело"
    assert body["course"] == 5
    assert EducationProfileHistory.objects.filter(user=learner).count() == 1


def test_switching_to_doctor_clears_course(learner, as_user, sechenov):
    client = as_user(learner)
    client.put("/api/v1/me/education", {"status": "student", "course": 6}, format="json")

    body = client.put("/api/v1/me/education", {"status": "doctor", "graduation_year": 2025}, format="json").json()

    assert body["course"] is None
    assert body["graduation_year"] == 2025
    assert EducationProfileHistory.objects.filter(user=learner).count() == 2


def test_same_profile_twice_writes_history_once(learner, as_user):
    client = as_user(learner)
    client.put("/api/v1/me/education", {"status": "student", "course": 2}, format="json")
    client.put("/api/v1/me/education", {"status": "student", "course": 2}, format="json")

    assert EducationProfileHistory.objects.filter(user=learner).count() == 1


@pytest.mark.parametrize(
    ("data", "field"),
    [
        ({"status": "professor"}, "status"),
        ({"status": "student", "course": 7}, "course"),
        ({"status": "student", "university_id": 999999}, "university_id"),
        ({"status": "resident", "specialty_code": "31.05.01"}, None),
    ],
)
def test_validation(learner, as_user, data, field):
    response = as_user(learner).put("/api/v1/me/education", data, format="json")

    if field is None:
        assert response.status_code == 200, "unknown keys are ignored"
    else:
        assert response.status_code == 400
        assert field in response.json()["error"]["fields"]


def test_specialty_must_match_status(learner, as_user, general_medicine):
    data = {"status": "resident", "specialty_id": general_medicine.pk}

    response = as_user(learner).put("/api/v1/me/education", data, format="json")

    assert response.status_code == 400
    assert "specialty_id" in response.json()["error"]["fields"]


def test_faculty_must_belong_to_university(learner, as_user, sechenov):
    other = Faculty.objects.create(university=University.objects.get(short_name="РНИМУ им. Пирогова"), name="Лечебный")
    data = {"status": "student", "university_id": sechenov.pk, "faculty_id": other.pk}

    response = as_user(learner).put("/api/v1/me/education", data, format="json")

    assert response.status_code == 400
    assert "faculty_id" in response.json()["error"]["fields"]


def test_changing_university_drops_verification(learner, as_user, sechenov):
    client = as_user(learner)
    client.put("/api/v1/me/education", {"status": "student", "university_id": sechenov.pk}, format="json")
    EducationProfile.objects.filter(user=learner).update(verification_status="verified", verification_method="manual")
    other = University.objects.get(short_name="РНИМУ им. Пирогова")

    body = client.put("/api/v1/me/education", {"status": "student", "university_id": other.pk}, format="json").json()

    assert body["verification_status"] == "unverified"


def test_save_is_rate_limited(learner, as_user):
    client = as_user(learner)
    for course in [1, 2, 3, 4, 5, 6, 1, 2, 3, 4]:
        assert (
            client.put("/api/v1/me/education", {"status": "student", "course": course}, format="json").status_code
            == 200
        )

    assert client.put("/api/v1/me/education", {"status": "doctor"}, format="json").status_code == 429


def test_delete_profile(learner, as_user):
    client = as_user(learner)
    client.put("/api/v1/me/education", {"status": "doctor"}, format="json")

    assert client.delete("/api/v1/me/education").status_code == 204
    assert client.get("/api/v1/me/education").json()["status"] is None


def test_university_request_then_approval_fills_profile(learner, as_user):
    client = as_user(learner)
    client.put("/api/v1/me/education", {"status": "student", "course": 1}, format="json")

    response = client.post(
        "/api/v1/universities/requests", {"name": "Новый медуниверситет", "city": "Тула"}, format="json"
    )
    assert response.status_code == 201
    assert client.get("/api/v1/me/education").json()["university_request"]["name"] == "Новый медуниверситет"

    approve_request(UniversityRequest.objects.get(user=learner))

    body = client.get("/api/v1/me/education").json()
    assert body["university"]["name"] == "Новый медуниверситет"
    assert body["university_request"] is None


def test_merge_keeps_university_user_already_chose(learner, as_user, sechenov):
    client = as_user(learner)
    client.put("/api/v1/me/education", {"status": "student", "university_id": sechenov.pk}, format="json")
    client.post("/api/v1/universities/requests", {"name": "Пироговка"}, format="json")
    pirogov = University.objects.get(short_name="РНИМУ им. Пирогова")

    resolve_request(UniversityRequest.objects.get(user=learner), pirogov, UniversityRequest.Status.MERGED)

    assert client.get("/api/v1/me/education").json()["university"]["id"] == sechenov.pk


def test_university_requests_rate_limited(learner, as_user):
    client = as_user(learner)
    for i in range(3):
        assert (
            client.post("/api/v1/universities/requests", {"name": f"Вуз номер {i}"}, format="json").status_code == 201
        )

    assert client.post("/api/v1/universities/requests", {"name": "Ещё один вуз"}, format="json").status_code == 429


def test_requires_auth(api_client):
    assert api_client.get("/api/v1/me/education").status_code == 401
    assert api_client.get("/api/v1/universities").status_code == 401
