from django.conf import settings
from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType
from django.db import models

from apps.core.models import Platform, TimeStampedModel, choices_check, range_check


class FeedbackKind(models.TextChoices):
    BUG = "bug", "ошибка в приложении"
    CONTENT_ERROR = "content_error", "ошибка в контенте"
    IDEA = "idea", "предложение"
    RATING = "rating", "оценка"


class FeedbackStatus(models.TextChoices):
    NEW = "new", "новое"
    IN_PROGRESS = "in_progress", "в работе"
    RESOLVED = "resolved", "решено"
    REJECTED = "rejected", "отклонено"


class Feedback(TimeStampedModel):
    Kind = FeedbackKind

    Status = FeedbackStatus

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    kind = models.CharField(max_length=16, choices=Kind)
    content_type = models.ForeignKey(ContentType, null=True, blank=True, on_delete=models.SET_NULL)
    object_id = models.PositiveBigIntegerField(null=True, blank=True)
    content_object = GenericForeignKey("content_type", "object_id")
    screen = models.CharField(max_length=64, blank=True)
    rating = models.PositiveSmallIntegerField(null=True, blank=True)
    text = models.TextField(blank=True, max_length=4000)
    app_version = models.CharField(max_length=32, blank=True)
    platform = models.CharField(max_length=16, choices=Platform, blank=True)
    status = models.CharField(max_length=16, choices=Status, default=Status.NEW)
    handled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = "обратная связь"
        verbose_name_plural = "обратная связь"
        constraints = [
            choices_check("kind", FeedbackKind),
            choices_check("status", FeedbackStatus),
            range_check("rating", 1, 5, nullable=True),
        ]
        indexes = [models.Index(fields=["kind", "status"])]
