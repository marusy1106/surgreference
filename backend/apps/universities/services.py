from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.core import ratelimit

from .models import (
    EducationProfile,
    EducationProfileHistory,
    EducationStatus,
    SpecialtyLevel,
    University,
    UniversityRequest,
    UniversityRequestStatus,
)

DAY = 24 * 3600

# Какой уровень специальности подходит статусу; у врача — любой.
SPECIALTY_LEVEL = {
    EducationStatus.STUDENT: SpecialtyLevel.SPECIALITET,
    EducationStatus.RESIDENT: SpecialtyLevel.RESIDENCY,
    EducationStatus.POSTGRADUATE: SpecialtyLevel.POSTGRADUATE,
}


def snapshot(profile):
    return {
        "status": profile.status,
        "university": {"id": profile.university_id, "name": str(profile.university)} if profile.university else None,
        "faculty": {"id": profile.faculty_id, "name": profile.faculty.name} if profile.faculty else None,
        "specialty": {"id": profile.specialty_id, "code": profile.specialty.code} if profile.specialty else None,
        "course": profile.course,
        "study_year": profile.study_year,
        "graduation_year": profile.graduation_year,
    }


@transaction.atomic
def save_profile(
    user, *, status, university=None, faculty=None, specialty=None, course=None, study_year=None, graduation_year=None
):
    """Поля, не относящиеся к статусу, очищаются (у врача нет курса). Смена вуза снимает подтверждение.
    Каждое изменение пишется в историю."""
    # Смена вуза влияет на рейтинг вузов — не чаще 10 сохранений в сутки.
    ratelimit.enforce("education-save", str(user.pk), 10, DAY)
    if faculty is not None and faculty.university_id != getattr(university, "pk", None):
        raise ValidationError({"faculty_id": ["Факультет не относится к выбранному вузу"]})
    level = SPECIALTY_LEVEL.get(status)
    if specialty is not None and level is not None and specialty.level != level:
        raise ValidationError({"specialty_id": ["Специальность не подходит к статусу"]})

    profile = EducationProfile.objects.select_for_update().filter(user=user).first() or EducationProfile(user=user)
    before = snapshot(profile) if profile.pk else None
    if profile.pk and profile.university_id != getattr(university, "pk", None):
        profile.verification_status = EducationProfile.VerificationStatus.UNVERIFIED
        profile.verification_method = ""
        profile.verified_at = None
    profile.status = status
    profile.university = university
    profile.faculty = faculty
    profile.specialty = specialty
    profile.course = course if status == EducationStatus.STUDENT else None
    profile.study_year = study_year if status in (EducationStatus.RESIDENT, EducationStatus.POSTGRADUATE) else None
    profile.graduation_year = graduation_year
    profile.save()
    after = snapshot(profile)
    if after != before:
        EducationProfileHistory.objects.create(user=user, snapshot=after)
    return profile


@transaction.atomic
def delete_profile(user):
    """История остаётся до удаления аккаунта: по ней видно, за какой вуз начислялись прошлые очки."""
    deleted, _ = EducationProfile.objects.filter(user=user).delete()
    if deleted:
        EducationProfileHistory.objects.create(user=user, snapshot={"status": None})


def request_university(user, *, name, city):
    """«Моего вуза нет» — заявка на модерацию; после одобрения вуз попадает в профиль сам."""
    ratelimit.enforce("university-request", str(user.pk), 3, DAY)
    return UniversityRequest.objects.create(user=user, name=name.strip(), city=city.strip())


@transaction.atomic
def resolve_request(request, university, status):
    """Одобрить (вуз создан из заявки) или объединить с существующим — и подставить вуз в профиль,
    если пользователь ещё не выбрал другой."""
    request.status = status
    request.resolved_university = university
    request.save(update_fields=["status", "resolved_university", "updated_at"])
    EducationProfile.objects.filter(user=request.user, university__isnull=True).update(
        university=university, updated_at=timezone.now()
    )


def approve_request(request):
    university, _ = University.objects.get_or_create(
        name=request.name, city=request.city or "—", defaults={"source": f"заявка пользователя #{request.pk}"}
    )
    resolve_request(request, university, UniversityRequestStatus.APPROVED)
    return university


def reject_request(request):
    request.status = UniversityRequestStatus.REJECTED
    request.save(update_fields=["status", "updated_at"])
