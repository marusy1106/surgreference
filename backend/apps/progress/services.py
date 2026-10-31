from decimal import ROUND_HALF_UP, Decimal

from django.db import IntegrityError, transaction
from django.utils import timezone

from apps.assessment import selectors as assessment

from .models import LessonProgress, TopicMastery
from .signals import lesson_completed

# Освоение — по последним 20 ответам темы, с весом сложности (docs/05-learning.md, 5.5).
MASTERY_WINDOW = 20


@transaction.atomic
def complete_lesson(user, lesson) -> bool:
    """True — урок пройден впервые (дальше начисляется XP)."""
    try:
        with transaction.atomic():
            LessonProgress.objects.create(
                user=user,
                lesson=lesson,
                revision=lesson.published_revision,
                completed_at=timezone.now(),
            )
    except IntegrityError:
        return False
    lesson_completed.send(sender=LessonProgress, user=user, lesson=lesson)
    return True


def update_topic_mastery(user, topic_id):
    answers = list(assessment.recent_topic_answers(user, topic_id, MASTERY_WINDOW))
    weight = sum(a.question.difficulty for a in answers)
    got = sum(a.question.difficulty for a in answers if a.is_correct)
    mastery = (Decimal(got) / weight if weight else Decimal(0)).quantize(Decimal("0.001"), ROUND_HALF_UP)
    totals = assessment.topic_answer_totals(user, topic_id)
    TopicMastery.objects.update_or_create(
        user=user,
        topic_id=topic_id,
        defaults={"mastery": mastery, "answered": totals["answered"], "correct": totals["correct"]},
    )


def on_quiz_attempt_finished(sender, attempt, **kwargs):
    topics = set(assessment.attempt_answers(attempt).values_list("question__topic_id", flat=True))
    for topic_id in topics:
        update_topic_mastery(attempt.user, topic_id)
