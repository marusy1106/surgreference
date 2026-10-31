from django.db.models import Max
from django.shortcuts import get_object_or_404

from apps.content.models import CatalogStatus, ReviewStatus

from .models import CaseAttempt, CaseAttemptStatus, CaseChoice, CaseStepKind, ClinicalCase


def published_cases(**filters):
    return (
        ClinicalCase.objects.filter(
            status=ReviewStatus.PUBLISHED,
            discipline__status=CatalogStatus.PUBLISHED,
            **filters,
        )
        .select_related("discipline")
        .order_by("discipline__sort_order", "title")
    )


def published_case(case_id):
    return get_object_or_404(published_cases(), pk=case_id)


def decision_steps(case):
    """В MVP кейс — последовательность шагов-решений (ветвление через next_step — до 2 веток)."""
    return list(case.steps.filter(kind=CaseStepKind.DECISION).prefetch_related("choices").order_by("sort_order"))


def user_attempt(user, attempt_id, *, status=None):
    filters = {"status": status} if status else {}
    return get_object_or_404(
        CaseAttempt.objects.select_related("case__discipline"),
        pk=attempt_id,
        user=user,
        **filters,
    )


def current_step(attempt):
    """Шаг, на котором стоит попытка; None — кейс пройден."""
    steps = decision_steps(attempt.case)
    if not attempt.path:
        return steps[0] if steps else None
    last = CaseChoice.objects.select_related("step").get(pk=attempt.path[-1])
    if last.next_step_id:
        return next((s for s in steps if s.pk == last.next_step_id), None)
    later = [s for s in steps if s.sort_order > last.step.sort_order]
    return later[0] if later else None


def best_previous_score(attempt):
    return (
        CaseAttempt.objects.filter(user=attempt.user, case=attempt.case, status=CaseAttemptStatus.FINISHED)
        .exclude(pk=attempt.pk)
        .aggregate(best=Max("score"))["best"]
    )


def chosen_path(attempt):
    by_id = CaseChoice.objects.select_related("step").prefetch_related("step__choices").in_bulk(attempt.path)
    return [by_id[i] for i in attempt.path if i in by_id]
