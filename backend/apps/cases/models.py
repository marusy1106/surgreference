from django.conf import settings
from django.contrib.postgres.fields import ArrayField
from django.db import models
from django.db.models import Q
from django.utils import timezone

from apps.content.models import (
    ReviewedContent,
    ReviewStatus,
    reviewed_content_constraints,
)
from apps.core.models import UUIDModel, choices_check, range_check


class ClinicalCase(ReviewedContent):
    """Учебный кейс. Пациенты только вымышленные: is_synthetic закреплён ограничением БД,
    публикация требует подтверждения рецензентом (synthetic_attested_by)."""

    discipline = models.ForeignKey("content.Discipline", on_delete=models.PROTECT, related_name="cases")
    title = models.CharField(max_length=255)
    summary = models.TextField(blank=True)
    debrief = models.TextField(
        "итоговый разбор", blank=True, help_text="Оптимальный путь, ключевые ошибки, что повторить"
    )
    difficulty = models.PositiveSmallIntegerField(default=2)
    version = models.PositiveIntegerField(default=1)
    previous_version = models.ForeignKey(
        "self",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="next_versions",
    )
    is_synthetic = models.BooleanField(default=True, editable=False)
    synthetic_attested_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="+",
    )
    is_premium = models.BooleanField(default=False)

    class Meta:
        verbose_name = "клинический кейс"
        verbose_name_plural = "клинические кейсы"
        constraints = [
            *reviewed_content_constraints(),
            range_check("difficulty", 1, 3),
            models.CheckConstraint(condition=Q(is_synthetic=True), name="cases_clinicalcase_only_synthetic"),
            models.CheckConstraint(
                condition=~Q(status=ReviewStatus.PUBLISHED) | Q(synthetic_attested_by__isnull=False),
                name="cases_clinicalcase_published_attested",
            ),
        ]

    def __str__(self):
        return self.title


class CaseStepKind(models.TextChoices):
    NARRATIVE = "narrative", "данные"
    DECISION = "decision", "решение"
    QUESTION = "question", "вопрос"


class CaseStep(models.Model):
    """content — {"title", "situation", "prompt", "summary"}; summary — краткая запись шага для истории."""

    Kind = CaseStepKind

    case = models.ForeignKey(ClinicalCase, on_delete=models.CASCADE, related_name="steps")
    sort_order = models.PositiveSmallIntegerField()
    kind = models.CharField(max_length=16, choices=Kind)
    content = models.JSONField(default=list)

    class Meta:
        ordering = ["sort_order"]
        constraints = [
            choices_check("kind", CaseStepKind),
            models.UniqueConstraint(fields=["case", "sort_order"], name="cases_casestep_order_uniq"),
        ]


class CaseChoiceQuality(models.TextChoices):
    OPTIMAL = "optimal", "оптимально"
    ACCEPTABLE = "acceptable", "допустимо"
    WRONG = "wrong", "ошибочно"
    DANGEROUS = "dangerous", "опасно"


class CaseChoice(models.Model):
    Quality = CaseChoiceQuality

    step = models.ForeignKey(CaseStep, on_delete=models.CASCADE, related_name="choices")
    text = models.TextField()
    quality = models.CharField(max_length=16, choices=Quality)
    score_delta = models.SmallIntegerField(default=0)
    feedback = models.TextField()
    next_step = models.ForeignKey(CaseStep, null=True, blank=True, on_delete=models.SET_NULL, related_name="+")
    sort_order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ["sort_order"]
        constraints = [choices_check("quality", CaseChoiceQuality)]


class CaseAttemptStatus(models.TextChoices):
    IN_PROGRESS = "in_progress", "идёт"
    FINISHED = "finished", "завершена"
    ABANDONED = "abandoned", "брошена"


class CaseAttempt(UUIDModel):
    Status = CaseAttemptStatus

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="case_attempts")
    case = models.ForeignKey(ClinicalCase, on_delete=models.PROTECT, related_name="attempts")
    status = models.CharField(max_length=16, choices=Status, default=Status.IN_PROGRESS)
    started_at = models.DateTimeField(default=timezone.now)
    finished_at = models.DateTimeField(null=True, blank=True)
    score = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    path = ArrayField(models.BigIntegerField(), default=list, blank=True)
    xp_awarded = models.IntegerField(default=0)

    class Meta:
        verbose_name = "попытка кейса"
        verbose_name_plural = "попытки кейсов"
        constraints = [choices_check("status", CaseAttemptStatus)]
        indexes = [models.Index(fields=["user", "-finished_at"])]
