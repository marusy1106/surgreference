from django.conf import settings
from django.db import models

from apps.core.models import choices_check


class AppendOnlyError(RuntimeError):
    pass


class AppendOnlyModel(models.Model):
    """Журнал: запись только вставкой. Дополнительно на prod у роли приложения
    отзываются права UPDATE/DELETE на эти таблицы (см. infra/postgres/roles.sql)."""

    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        if not self._state.adding:
            raise AppendOnlyError(f"{type(self).__name__} нельзя изменять")
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise AppendOnlyError(f"{type(self).__name__} нельзя удалять")


class SecurityEventOutcome(models.TextChoices):
    SUCCESS = "success", "успех"
    FAILURE = "failure", "неудача"


class SecurityEvent(AppendOnlyModel):
    Outcome = SecurityEventOutcome

    occurred_at = models.DateTimeField(auto_now_add=True, db_index=True)
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    subject = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    event = models.CharField(max_length=64, db_index=True)
    outcome = models.CharField(max_length=16, choices=Outcome)
    ip = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=256, blank=True)
    details = models.JSONField(default=dict, blank=True)

    class Meta:
        verbose_name = "событие безопасности"
        verbose_name_plural = "журнал безопасности"
        ordering = ["-occurred_at"]
        constraints = [choices_check("outcome", SecurityEventOutcome)]


class AdminAuditLog(AppendOnlyModel):
    occurred_at = models.DateTimeField(auto_now_add=True, db_index=True)
    staff_user = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+")
    action = models.CharField(max_length=32)
    model = models.CharField(max_length=128)
    object_id = models.CharField(max_length=64)
    diff = models.JSONField(default=dict, blank=True)
    ip = models.GenericIPAddressField(null=True, blank=True)

    class Meta:
        verbose_name = "действие в админке"
        verbose_name_plural = "журнал действий в админке"
        ordering = ["-occurred_at"]
