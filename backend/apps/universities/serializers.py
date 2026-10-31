from django.utils import timezone
from rest_framework import serializers

from .models import EducationStatus, Faculty, Specialty, University


def university_payload(u):
    return {"id": u.pk, "name": u.name, "short_name": u.short_name, "city": u.city}


def specialty_payload(s):
    return {"id": s.pk, "code": s.code, "name": s.name, "level": s.level}


def profile_payload(profile, request=None):
    """Профиль может быть не заполнен — тогда status = null, а приложение предлагает его заполнить."""
    pending = {"name": request.name, "city": request.city} if request else None
    if profile is None:
        return {
            "status": None,
            "university": None,
            "faculty": None,
            "specialty": None,
            "course": None,
            "study_year": None,
            "graduation_year": None,
            "verification_status": "unverified",
            "university_request": pending,
        }
    return {
        "status": profile.status,
        "university": university_payload(profile.university) if profile.university else None,
        "faculty": {"id": profile.faculty_id, "name": profile.faculty.name} if profile.faculty else None,
        "specialty": specialty_payload(profile.specialty) if profile.specialty else None,
        "course": profile.course,
        "study_year": profile.study_year,
        "graduation_year": profile.graduation_year,
        "verification_status": profile.verification_status,
        "university_request": pending,
    }


class EducationInputSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=EducationStatus.choices)
    university_id = serializers.PrimaryKeyRelatedField(
        queryset=University.objects.filter(is_active=True), source="university", required=False, allow_null=True
    )
    faculty_id = serializers.PrimaryKeyRelatedField(
        queryset=Faculty.objects.filter(is_active=True), source="faculty", required=False, allow_null=True
    )
    specialty_id = serializers.PrimaryKeyRelatedField(
        queryset=Specialty.objects.all(), source="specialty", required=False, allow_null=True
    )
    course = serializers.IntegerField(min_value=1, max_value=6, required=False, allow_null=True)
    study_year = serializers.IntegerField(min_value=1, max_value=5, required=False, allow_null=True)
    graduation_year = serializers.IntegerField(min_value=1950, required=False, allow_null=True)

    def validate_graduation_year(self, value):
        if value is not None and value > timezone.now().year + 10:
            raise serializers.ValidationError("Слишком далёкий год выпуска")
        return value


class UniversityRequestSerializer(serializers.Serializer):
    name = serializers.CharField(min_length=3, max_length=255)
    city = serializers.CharField(max_length=128, allow_blank=True, required=False, default="")
