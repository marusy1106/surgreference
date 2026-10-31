import random
from datetime import timedelta
from decimal import Decimal

from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.content.models import ReviewStatus
from apps.core import ratelimit

from .models import (
    AttemptAnswer,
    Question,
    QuestionKind,
    QuizAttempt,
    QuizAttemptMode,
    QuizAttemptStatus,
    QuizQuestion,
)
from .signals import quiz_attempt_finished

HOUR = 3600
ATTEMPT_TTL = timedelta(hours=24)

# Ответ быстрее этого в среднем по попытке — похоже на автоматизацию (docs/04, антифрод).
SUSPICIOUS_AVG_ANSWER_MS = 1500


@transaction.atomic
def start_attempt(user, quiz):
    """Тест темы: фиксирует набор вопросов (опубликованные версии) и порядок вариантов. Прежние
    незавершённые попытки этого теста закрываются как брошенные."""
    links = (
        QuizQuestion.objects.filter(quiz=quiz, question__status=ReviewStatus.PUBLISHED)
        .select_related("question")
        .prefetch_related("question__options")
        .order_by("sort_order")[: quiz.question_count]
    )
    questions = [link.question for link in links]
    if not questions:
        raise ValidationError({"quiz": ["В тесте пока нет опубликованных вопросов"]})
    return _open_attempt(user, questions, quiz=quiz, discipline=quiz.discipline, mode=QuizAttemptMode.TOPIC)


@transaction.atomic
def start_practice(user, discipline, mode, question_ids):
    """Тренировка и работа над ошибками: вопросы дисциплины без привязки к тесту. Набор выбирает
    вызывающий модуль (progress — по освоению тем или по ошибкам)."""
    by_id = Question.objects.filter(pk__in=question_ids, status=ReviewStatus.PUBLISHED).prefetch_related("options")
    by_id = {q.pk: q for q in by_id}
    questions = [by_id[i] for i in question_ids if i in by_id]
    if not questions:
        raise ValidationError({"discipline": ["В дисциплине пока нет опубликованных вопросов"]})
    return _open_attempt(user, questions, quiz=None, discipline=discipline, mode=mode)


def _open_attempt(user, questions, *, quiz, discipline, mode):
    ratelimit.enforce("quiz-start", str(user.pk), 30, HOUR)
    QuizAttempt.objects.filter(
        user=user, quiz=quiz, discipline=discipline, mode=mode, status=QuizAttemptStatus.IN_PROGRESS
    ).update(status=QuizAttemptStatus.ABANDONED)
    attempt = QuizAttempt.objects.create(
        user=user,
        quiz=quiz,
        discipline=discipline,
        mode=mode,
        total_count=len(questions),
    )
    AttemptAnswer.objects.bulk_create(
        AttemptAnswer(
            attempt=attempt,
            question=question,
            position=position,
            option_order=random.sample(ids := [o.pk for o in question.options.all()], len(ids)),
        )
        for position, question in enumerate(questions)
    )
    return attempt


@transaction.atomic
def answer(attempt, *, question_id, option_ids):
    """Ответ можно менять до завершения попытки. Время ответа считает сервер."""
    attempt = QuizAttempt.objects.select_for_update().get(pk=attempt.pk)
    if attempt.status != QuizAttemptStatus.IN_PROGRESS:
        raise ValidationError({"attempt": ["Попытка уже завершена"]})
    row = AttemptAnswer.objects.select_related("question").filter(attempt=attempt, question_id=question_id).first()
    if row is None:
        raise ValidationError({"question_id": ["Этого вопроса нет в попытке"]})
    selected = list(dict.fromkeys(option_ids))
    if not set(selected) <= set(row.option_order):
        raise ValidationError({"option_ids": ["Неизвестный вариант ответа"]})
    if row.question.kind == QuestionKind.SINGLE and len(selected) != 1:
        raise ValidationError({"option_ids": ["Нужно выбрать один вариант"]})
    if not selected:
        raise ValidationError({"option_ids": ["Выберите хотя бы один вариант"]})

    now = timezone.now()
    previous = (
        AttemptAnswer.objects.filter(attempt=attempt, answered_at__isnull=False)
        .exclude(pk=row.pk)
        .order_by("-answered_at")
        .values_list("answered_at", flat=True)
        .first()
    )
    since = previous or attempt.started_at
    row.selected_option_ids = selected
    row.answered_at = now
    row.time_spent_ms = max(0, int((now - since).total_seconds() * 1000))
    row.save(update_fields=["selected_option_ids", "answered_at", "time_spent_ms"])


@transaction.atomic
def finish(attempt):
    """Подсчёт результата. Повторный вызов возвращает ту же попытку (идемпотентно)."""
    attempt = QuizAttempt.objects.select_for_update().get(pk=attempt.pk)
    if attempt.status == QuizAttemptStatus.FINISHED:
        return attempt
    if attempt.status != QuizAttemptStatus.IN_PROGRESS:
        raise ValidationError({"attempt": ["Попытка закрыта, начните тест заново"]})

    rows = list(AttemptAnswer.objects.filter(attempt=attempt).prefetch_related("question__options"))
    correct = 0
    for row in rows:
        right = {o.pk for o in row.question.options.all() if o.is_correct}
        row.is_correct = bool(row.selected_option_ids) and set(row.selected_option_ids) == right
        correct += row.is_correct
    AttemptAnswer.objects.bulk_update(rows, ["is_correct"])

    timed = [r.time_spent_ms for r in rows if r.time_spent_ms is not None]
    attempt.status = QuizAttemptStatus.FINISHED
    attempt.finished_at = timezone.now()
    attempt.correct_count = correct
    attempt.total_count = len(rows)
    attempt.score = Decimal(correct) / len(rows) if rows else Decimal(0)
    attempt.flagged = bool(timed) and sum(timed) / len(timed) < SUSPICIOUS_AVG_ANSWER_MS
    attempt.save()
    quiz_attempt_finished.send(sender=QuizAttempt, attempt=attempt)
    attempt.refresh_from_db()
    return attempt


def set_xp_awarded(attempt, amount):
    """Пишет gamification после начисления — чтобы ответ finish сразу содержал XP."""
    QuizAttempt.objects.filter(pk=attempt.pk).update(xp_awarded=amount)


def expire_attempts():
    cutoff = timezone.now() - ATTEMPT_TTL
    return QuizAttempt.objects.filter(status=QuizAttemptStatus.IN_PROGRESS, started_at__lt=cutoff).update(
        status=QuizAttemptStatus.ABANDONED
    )
