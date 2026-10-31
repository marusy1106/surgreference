from django.db.models import Count, Max, Q
from django.shortcuts import get_object_or_404

from apps.content.models import CatalogStatus, ReviewStatus

from .models import AttemptAnswer, Question, Quiz, QuizAttempt, QuizAttemptStatus


def stem_text(stem) -> str:
    """Условие вопроса — блоки; в MVP клиент показывает их как текст абзацами."""
    if isinstance(stem, str):
        return stem
    return "\n\n".join(block.get("text", "") for block in stem if isinstance(block, dict)).strip()


def published_quizzes(**filters):
    return Quiz.objects.filter(
        status=CatalogStatus.PUBLISHED,
        discipline__status=CatalogStatus.PUBLISHED,
        **filters,
    ).annotate(
        published_questions=Count(
            "quizquestion",
            filter=Q(quizquestion__question__status=ReviewStatus.PUBLISHED),
        )
    )


def published_quiz(quiz_id):
    return get_object_or_404(published_quizzes().select_related("topic", "discipline"), pk=quiz_id)


def topic_quizzes(topic_ids):
    """Тест темы для каждой темы: {topic_id: quiz} (если тестов несколько — первый по id)."""
    result = {}
    for quiz in published_quizzes(topic_id__in=topic_ids).filter(published_questions__gt=0).order_by("pk"):
        result.setdefault(quiz.topic_id, quiz)
    return result


def user_attempt(user, attempt_id, *, status=None):
    """Чужая попытка → 404 (без раскрытия её существования)."""
    filters = {"status": status} if status else {}
    return get_object_or_404(
        QuizAttempt.objects.select_related("quiz__topic", "discipline"),
        pk=attempt_id,
        user=user,
        **filters,
    )


def attempt_answers(attempt):
    return (
        AttemptAnswer.objects.filter(attempt=attempt).select_related("question").prefetch_related("question__options")
    )


def best_previous_correct(attempt) -> int | None:
    """Лучший результат пользователя по этому тесту до данной попытки; None — попытка первая."""
    return (
        QuizAttempt.objects.filter(user=attempt.user, quiz=attempt.quiz, status=QuizAttemptStatus.FINISHED)
        .exclude(pk=attempt.pk)
        .filter(finished_at__lt=attempt.finished_at)
        .aggregate(best=Max("correct_count"))["best"]
    )


def last_finished_attempt(user):
    return (
        QuizAttempt.objects.filter(user=user, status=QuizAttemptStatus.FINISHED, quiz__isnull=False)
        .select_related("quiz__topic", "discipline")
        .order_by("-finished_at")
        .first()
    )


def recent_topic_answers(user, topic_id, limit):
    """Последние ответы пользователя по вопросам темы в завершённых попытках (для освоения)."""
    return (
        AttemptAnswer.objects.filter(
            attempt__user=user,
            attempt__status=QuizAttemptStatus.FINISHED,
            question__topic_id=topic_id,
            is_correct__isnull=False,
        )
        .select_related("question")
        .order_by("-attempt__finished_at", "-position")[:limit]
    )


def topic_answer_totals(user, topic_id):
    return AttemptAnswer.objects.filter(
        attempt__user=user,
        attempt__status=QuizAttemptStatus.FINISHED,
        question__topic_id=topic_id,
        is_correct__isnull=False,
    ).aggregate(answered=Count("pk"), correct=Count("pk", filter=Q(is_correct=True)))


def published_question_counts(topic_ids):
    rows = (
        Question.objects.filter(topic_id__in=topic_ids, status=ReviewStatus.PUBLISHED)
        .values("topic_id")
        .annotate(n=Count("pk"))
    )
    return {r["topic_id"]: r["n"] for r in rows}
