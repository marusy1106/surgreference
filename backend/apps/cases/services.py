from decimal import Decimal

from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.core import ratelimit

from . import selectors
from .models import CaseAttempt, CaseAttemptStatus, CaseChoice
from .signals import case_attempt_finished

HOUR = 3600


@transaction.atomic
def start_attempt(user, case):
    ratelimit.enforce("case-start", str(user.pk), 30, HOUR)
    if not selectors.decision_steps(case):
        raise ValidationError({"case": ["В кейсе пока нет шагов"]})
    CaseAttempt.objects.filter(user=user, case=case, status=CaseAttemptStatus.IN_PROGRESS).update(
        status=CaseAttemptStatus.ABANDONED
    )
    return CaseAttempt.objects.create(user=user, case=case)


def _score(path):
    """Доля баллов: сумма выбранных против суммы лучших на пройденных шагах."""
    got = sum(choice.score_delta for choice in path)
    best = sum(max(c.score_delta for c in choice.step.choices.all()) for choice in path)
    return Decimal(max(got, 0)) / best if best > 0 else Decimal(1)


@transaction.atomic
def choose(attempt, choice_id):
    """Принять выбор на текущем шаге. Возвращает (выбор, следующий шаг или None, попытка)."""
    attempt = CaseAttempt.objects.select_for_update().select_related("case").get(pk=attempt.pk)
    if attempt.status != CaseAttemptStatus.IN_PROGRESS:
        raise ValidationError({"attempt": ["Кейс уже пройден, начните заново"]})
    step = selectors.current_step(attempt)
    choice = CaseChoice.objects.filter(pk=choice_id, step=step).select_related("step").first() if step else None
    if choice is None:
        raise ValidationError({"choice_id": ["Этот вариант не относится к текущему шагу"]})

    attempt.path = [*attempt.path, choice.pk]
    attempt.save(update_fields=["path", "updated_at"])
    next_step = selectors.current_step(attempt)
    if next_step is None:
        attempt.status = CaseAttemptStatus.FINISHED
        attempt.finished_at = timezone.now()
        attempt.score = _score(selectors.chosen_path(attempt))
        attempt.save(update_fields=["status", "finished_at", "score", "updated_at"])
        case_attempt_finished.send(sender=CaseAttempt, attempt=attempt)
        attempt.refresh_from_db()
    return choice, next_step, attempt


def set_xp_awarded(attempt, amount):
    CaseAttempt.objects.filter(pk=attempt.pk).update(xp_awarded=amount)
