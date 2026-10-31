from django.conf import settings
from django.db import models
from django.db.models import Q

from apps.core.models import TimeStampedModel, choices_check, range_check


class University(TimeStampedModel):
    name = models.CharField("название", max_length=255)
    short_name = models.CharField("сокращение", max_length=64, blank=True)
    city = models.CharField("город", max_length=128)
    region = models.CharField("регион", max_length=128, blank=True)
    is_active = models.BooleanField(default=True)
    source = models.CharField("источник записи", max_length=255, blank=True)

    class Meta:
        verbose_name = "вуз"
        verbose_name_plural = "вузы"
        ordering = ["name"]
        constraints = [models.UniqueConstraint(fields=["name", "city"], name="universities_university_name_city_uniq")]

    def __str__(self):
        return self.short_name or self.name


class Faculty(TimeStampedModel):
    university = models.ForeignKey(University, on_delete=models.CASCADE, related_name="faculties")
    name = models.CharField(max_length=255)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = "факультет"
        verbose_name_plural = "факультеты"
        constraints = [
            models.UniqueConstraint(
                fields=["university", "name"],
                name="universities_faculty_university_name_uniq",
            )
        ]

    def __str__(self):
        return self.name


class SpecialtyLevel(models.TextChoices):
    SPECIALITET = "specialitet", "специалитет"
    RESIDENCY = "residency", "ординатура"
    POSTGRADUATE = "postgraduate", "аспирантура"


class Specialty(TimeStampedModel):
    Level = SpecialtyLevel

    code = models.CharField("код ФГОС", max_length=16, unique=True)
    name = models.CharField(max_length=255)
    level = models.CharField(max_length=16, choices=Level)

    class Meta:
        verbose_name = "специальность"
        verbose_name_plural = "специальности"
        ordering = ["code"]
        constraints = [choices_check("level", SpecialtyLevel)]

    def __str__(self):
        return f"{self.code} {self.name}"


class UniversityEmailDomain(TimeStampedModel):
    """Задел для подтверждения принадлежности к вузу по вузовской почте."""

    university = models.ForeignKey(University, on_delete=models.CASCADE, related_name="email_domains")
    domain = models.CharField(max_length=255, unique=True)


class UniversityRequestStatus(models.TextChoices):
    NEW = "new", "новая"
    APPROVED = "approved", "одобрена"
    REJECTED = "rejected", "отклонена"
    MERGED = "merged", "объединена с существующим"


class UniversityRequest(TimeStampedModel):
    Status = UniversityRequestStatus

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="university_requests",
    )
    name = models.CharField(max_length=255)
    city = models.CharField(max_length=128, blank=True)
    status = models.CharField(max_length=16, choices=Status, default=Status.NEW)
    resolved_university = models.ForeignKey(University, null=True, blank=True, on_delete=models.SET_NULL)

    class Meta:
        verbose_name = "заявка на добавление вуза"
        verbose_name_plural = "заявки на добавление вузов"
        constraints = [choices_check("status", UniversityRequestStatus)]


class EducationStatus(models.TextChoices):
    STUDENT = "student", "студент"
    RESIDENT = "resident", "ординатор"
    POSTGRADUATE = "postgraduate", "аспирант"
    DOCTOR = "doctor", "врач"


class EducationProfileVerificationStatus(models.TextChoices):
    UNVERIFIED = "unverified", "не подтверждено"
    PENDING = "pending", "на проверке"
    VERIFIED = "verified", "подтверждено"
    REJECTED = "rejected", "отклонено"


class EducationProfileVerificationMethod(models.TextChoices):
    EDU_EMAIL = "edu_email", "вузовская почта"
    DOCUMENT = "document", "документ"
    MANUAL = "manual", "вручную"


class EducationProfile(models.Model):
    """Образовательный статус. Хранится отдельно от уровня знаний (gamification)."""

    VerificationStatus = EducationProfileVerificationStatus

    VerificationMethod = EducationProfileVerificationMethod

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        primary_key=True,
        on_delete=models.CASCADE,
        related_name="education",
    )
    status = models.CharField(max_length=16, choices=EducationStatus)
    university = models.ForeignKey(University, null=True, blank=True, on_delete=models.SET_NULL, related_name="+")
    faculty = models.ForeignKey(Faculty, null=True, blank=True, on_delete=models.SET_NULL, related_name="+")
    specialty = models.ForeignKey(Specialty, null=True, blank=True, on_delete=models.SET_NULL, related_name="+")
    course = models.PositiveSmallIntegerField("курс", null=True, blank=True)
    study_year = models.PositiveSmallIntegerField("год ординатуры/аспирантуры", null=True, blank=True)
    graduation_year = models.PositiveSmallIntegerField(null=True, blank=True)
    verification_status = models.CharField(
        max_length=16, choices=VerificationStatus, default=VerificationStatus.UNVERIFIED
    )
    verification_method = models.CharField(max_length=16, choices=VerificationMethod, blank=True)
    verified_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "образовательный профиль"
        verbose_name_plural = "образовательные профили"
        constraints = [
            choices_check("status", EducationStatus),
            choices_check("verification_status", EducationProfileVerificationStatus),
            range_check("course", 1, 6, nullable=True),
            range_check("study_year", 1, 5, nullable=True),
            models.CheckConstraint(
                condition=Q(course__isnull=True) | Q(status=EducationStatus.STUDENT),
                name="universities_profile_course_only_for_students",
            ),
            models.CheckConstraint(
                condition=Q(study_year__isnull=True)
                | Q(status__in=[EducationStatus.RESIDENT, EducationStatus.POSTGRADUATE]),
                name="universities_profile_study_year_only_for_residents",
            ),
        ]
        indexes = [models.Index(fields=["university", "status"])]


class EducationProfileHistory(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="education_history",
    )
    snapshot = models.JSONField()
    changed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-changed_at"]
