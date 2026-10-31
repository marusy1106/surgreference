from django.db.models import CharField, Value
from django.db.models.functions import Concat, Lower, Replace
from django.shortcuts import get_object_or_404

from .models import EducationProfile, EducationProfileHistory, Faculty, Specialty, University, UniversityRequest

SEARCH_LIMIT = 20


def _normalize(text: str) -> str:
    return text.lower().replace("ё", "е")


def search_universities(query: str):
    """Каждое слово запроса должно найтись в названии, сокращении, других названиях или городе:
    «пирогова москва», «сеченовка», «ПМГМУ». Регистр и «ё» не важны."""
    universities = University.objects.filter(is_active=True)
    words = _normalize(query).split()
    if words:
        haystack = Replace(
            Lower(Concat("name", Value(" "), "short_name", Value(" "), "aliases", Value(" "), "city")),
            Value("ё"),
            Value("е"),
            output_field=CharField(),
        )
        universities = universities.annotate(haystack=haystack)
        for word in words:
            universities = universities.filter(haystack__contains=word)
    return universities.order_by("name")[:SEARCH_LIMIT]


def active_university(university_id):
    return get_object_or_404(University, pk=university_id, is_active=True)


def faculties(university):
    return Faculty.objects.filter(university=university, is_active=True).order_by("name")


def specialties(level=None):
    rows = Specialty.objects.all()
    return rows.filter(level=level) if level else rows


def education_profile(user):
    return EducationProfile.objects.filter(user=user).select_related("university", "faculty", "specialty").first()


def open_request(user):
    return (
        UniversityRequest.objects.filter(user=user, status=UniversityRequest.Status.NEW).order_by("-created_at").first()
    )


def history(user):
    return EducationProfileHistory.objects.filter(user=user)
