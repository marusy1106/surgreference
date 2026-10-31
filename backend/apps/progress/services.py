import random
from decimal import ROUND_HALF_UP, Decimal

from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.assessment import selectors as assessment
from apps.assessment import services as assessment_services
from apps.assessment.models import QuizAttemptMode

from .models import LessonProgress, TopicMastery
from .selectors import MISTAKES_MIN, topic_mastery
from .signals import lesson_completed

# Освоение — по последним 20 ответам темы, с весом сложности (docs/05-learning.md, 5.5).
MASTERY_WINDOW = 20
PRACTICE_SIZE = 10


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


def start_training(user, discipline):
    """Случайные вопросы дисциплины; темы с низким освоением выпадают чаще. Вес темы 1,1 − освоение:
    у неначатой темы 1,1, у освоенной полностью 0,1 — она всё равно иногда попадается для повторения."""
    questions = assessment.discipline_questions(discipline)
    mastery = topic_mastery(user, {topic_id for _, topic_id in questions})

    def weight(topic_id):
        return 1.1 - (float(mastery[topic_id].mastery) if topic_id in mastery else 0)

    # Взвешенная выборка без повторов (Efraimidis–Spirakis): ключ u^(1/w), берём наибольшие.
    keyed = sorted(questions, key=lambda q: random.random() ** (1 / weight(q[1])), reverse=True)  # noqa: S311 — не криптография
    picked = [question_id for question_id, _ in keyed[:PRACTICE_SIZE]]
    return assessment_services.start_practice(user, discipline, QuizAttemptMode.TRAINING, picked)


def start_mistakes(user, discipline):
    """Вопросы, последний ответ на которые неверный. Верный ответ здесь убирает вопрос из ошибок."""
    wrong = assessment.mistakes(user, [discipline.pk]).get(discipline.pk, [])
    if len(wrong) < MISTAKES_MIN:
        raise ValidationError(
            {"discipline": [f"Работа над ошибками откроется после {MISTAKES_MIN} ошибок, сейчас их {len(wrong)}"]}
        )
    picked = random.sample(wrong, min(len(wrong), PRACTICE_SIZE))
    return assessment_services.start_practice(user, discipline, QuizAttemptMode.MISTAKES, picked)
