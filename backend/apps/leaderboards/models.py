from django.db import models

from apps.core.models import choices_check


class LeaderboardSnapshotBoard(models.TextChoices):
    USERS_GLOBAL = "users_global", "все студенты"
    USERS_UNIVERSITY = "users_university", "студенты вуза"
    UNIVERSITIES = "universities", "вузы"


class LeaderboardSnapshotPeriod(models.TextChoices):
    WEEK = "week", "неделя"
    MONTH = "month", "месяц"
    ALL_TIME = "all_time", "всё время"


class LeaderboardSnapshot(models.Model):
    """Итоговые места за период. «Живой» рейтинг хранится в Redis sorted sets."""

    Board = LeaderboardSnapshotBoard

    Period = LeaderboardSnapshotPeriod

    board = models.CharField(max_length=24, choices=Board)
    period = models.CharField(max_length=16, choices=Period)
    period_start = models.DateField()
    university = models.ForeignKey(
        "universities.University",
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="+",
    )
    entity_id = models.CharField("id пользователя или вуза", max_length=36)
    rank = models.PositiveIntegerField()
    score = models.DecimalField(max_digits=12, decimal_places=2)
    participants = models.PositiveIntegerField(default=0)
    computed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            choices_check("board", LeaderboardSnapshotBoard),
            choices_check("period", LeaderboardSnapshotPeriod),
            models.UniqueConstraint(
                fields=["board", "period", "period_start", "university", "entity_id"],
                name="leaderboards_snapshot_entity_uniq",
                nulls_distinct=False,
            ),
        ]
        indexes = [models.Index(fields=["board", "period", "period_start", "rank"])]
