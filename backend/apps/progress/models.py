from django.conf import settings
from django.db import models
from django.db.models import Q


class LessonProgress(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="lesson_progress",
    )
    lesson = models.ForeignKey("content.Lesson", on_delete=models.CASCADE, related_name="+")
    revision = models.ForeignKey("content.LessonRevision", null=True, on_delete=models.SET_NULL, related_name="+")
    completed_at = models.DateTimeField()

    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "lesson"], name="progress_lessonprogress_uniq")]


class TopicMastery(models.Model):
    """Освоение темы: взвешенная доля верных по последним ответам (0..1)."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="topic_mastery")
    topic = models.ForeignKey("content.Topic", on_delete=models.CASCADE, related_name="+")
    answered = models.PositiveIntegerField(default=0)
    correct = models.PositiveIntegerField(default=0)
    mastery = models.DecimalField(max_digits=4, decimal_places=3, default=0)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "topic"], name="progress_topicmastery_uniq"),
            models.CheckConstraint(
                condition=Q(mastery__gte=0) & Q(mastery__lte=1),
                name="progress_mastery_range",
            ),
            models.CheckConstraint(
                condition=Q(correct__lte=models.F("answered")),
                name="progress_correct_lte_answered",
            ),
        ]
