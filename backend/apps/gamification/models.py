from django.conf import settings
from django.db import models

from apps.core.models import choices_check


class XpReason(models.TextChoices):
    LESSON_COMPLETED = "lesson_completed", "урок пройден"
    QUIZ_CORRECT = "quiz_correct", "верные ответы"
    QUIZ_BONUS = "quiz_bonus", "бонус за результат"
    CASE_COMPLETED = "case_completed", "кейс завершён"
    STREAK = "streak", "серия дней"
    ACHIEVEMENT = "achievement", "достижение"
    REVERSAL = "reversal", "сторно"


class XpEvent(models.Model):
    """XP-журнал — источник истины. Только вставка; idempotency_key исключает двойное начисление."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="xp_events")
    amount = models.IntegerField()
    reason = models.CharField(max_length=32, choices=XpReason)
    source_type = models.CharField(max_length=32)
    source_id = models.CharField(max_length=64)
    # Снимок вуза на момент начисления: при смене вуза прошлые очки остаются за прежним.
    university = models.ForeignKey(
        "universities.University",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    idempotency_key = models.CharField(max_length=128, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "начисление XP"
        verbose_name_plural = "журнал XP"
        constraints = [choices_check("reason", XpReason)]
        indexes = [
            models.Index(fields=["user", "created_at"]),
            models.Index(fields=["created_at"]),
        ]


class UserStats(models.Model):
    """Денормализованные показатели для быстрого чтения; пересчитываются из журналов."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        primary_key=True,
        on_delete=models.CASCADE,
        related_name="stats",
    )
    total_xp = models.PositiveIntegerField(default=0)
    level = models.PositiveSmallIntegerField(default=1)
    current_streak = models.PositiveIntegerField(default=0)
    longest_streak = models.PositiveIntegerField(default=0)
    last_active_date = models.DateField(null=True, blank=True)
    quizzes_finished = models.PositiveIntegerField(default=0)
    cases_finished = models.PositiveIntegerField(default=0)
    lessons_completed = models.PositiveIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)


class Achievement(models.Model):
    code = models.SlugField(max_length=64, unique=True)
    title = models.CharField(max_length=128)
    description = models.CharField(max_length=500)
    icon = models.CharField(max_length=64, blank=True)
    criteria = models.JSONField(help_text='Напр. {"type": "count", "metric": "quizzes_finished", "gte": 10}')
    xp_reward = models.PositiveIntegerField(default=0)
    is_hidden = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = "достижение"
        verbose_name_plural = "достижения"

    def __str__(self):
        return self.title


class UserAchievement(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="achievements")
    achievement = models.ForeignKey(Achievement, on_delete=models.PROTECT, related_name="+")
    earned_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "achievement"], name="gamification_userachievement_uniq")
        ]
