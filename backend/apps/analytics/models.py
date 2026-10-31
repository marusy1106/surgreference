import uuid

from django.conf import settings
from django.contrib.postgres.indexes import BrinIndex
from django.db import models

from apps.core.models import Platform


class AnalyticsEvent(models.Model):
    """Псевдонимизированные события: только UUID, без email/имени. Ключи props — по белому списку."""

    event = models.CharField(max_length=64)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    install_id = models.UUIDField()
    session_id = models.UUIDField(null=True, blank=True)
    occurred_at = models.DateTimeField()
    received_at = models.DateTimeField(auto_now_add=True)
    platform = models.CharField(max_length=16, choices=Platform, blank=True)
    app_version = models.CharField(max_length=32, blank=True)
    props = models.JSONField(default=dict, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["event", "occurred_at"]),
            BrinIndex(fields=["occurred_at"], name="analytics_event_occurred_brin"),
        ]


class AppSession(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    install_id = models.UUIDField()
    platform = models.CharField(max_length=16, choices=Platform)
    started_at = models.DateTimeField()
    last_seen_at = models.DateTimeField()
    ended_at = models.DateTimeField(null=True, blank=True)
    duration_sec = models.PositiveIntegerField(default=0)

    class Meta:
        indexes = [
            models.Index(fields=["started_at"]),
            models.Index(fields=["user", "started_at"]),
        ]


class DailyUserActivity(models.Model):
    """Основа DAU/MAU/retention: одна строка на активного пользователя в день."""

    date = models.DateField()
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")
    sessions = models.PositiveIntegerField(default=0)
    active_seconds = models.PositiveIntegerField(default=0)
    quizzes = models.PositiveIntegerField(default=0)
    lessons = models.PositiveIntegerField(default=0)
    cases = models.PositiveIntegerField(default=0)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["date", "user"], name="analytics_daily_activity_uniq")]
        indexes = [models.Index(fields=["user", "date"])]


class DailyMetrics(models.Model):
    """Ночные агрегаты без ПД — хранятся бессрочно."""

    date = models.DateField(primary_key=True)
    registered = models.PositiveIntegerField(default=0)
    confirmed = models.PositiveIntegerField(default=0)
    dau = models.PositiveIntegerField(default=0)
    wau = models.PositiveIntegerField(default=0)
    mau = models.PositiveIntegerField(default=0)
    quizzes_finished = models.PositiveIntegerField(default=0)
    cases_finished = models.PositiveIntegerField(default=0)
    lessons_completed = models.PositiveIntegerField(default=0)
    avg_session_sec = models.PositiveIntegerField(default=0)
    median_session_sec = models.PositiveIntegerField(default=0)
    computed_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "метрики дня"
        verbose_name_plural = "метрики по дням"
        ordering = ["-date"]
