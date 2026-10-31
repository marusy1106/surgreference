from django.db.models import Q
from django.utils import timezone

from . import flags
from .models import EntitlementGrant, Plan, PlanFeature, Subscription


def effective_plan(user) -> Plan | None:
    now = timezone.now()
    subscription = (
        Subscription.objects.filter(
            user=user,
            status__in=Subscription.ENTITLED_STATUSES,
            current_period_end__gt=now,
        )
        .select_related("plan")
        .order_by("-current_period_end")
        .first()
    )
    if subscription:
        return subscription.plan
    return Plan.objects.filter(code=Plan.FREE).first()


def _has_active_grant(user, key: str) -> bool:
    now = timezone.now()
    return (
        EntitlementGrant.objects.filter(user=user, starts_at__lte=now)
        .filter(Q(expires_at__isnull=True) | Q(expires_at__gt=now))
        .filter(Q(feature__key=key) | Q(plan__planfeature__feature__key=key))
        .exists()
    )


def has_feature(user, key: str) -> bool:
    """Единственная точка проверки доступа к функциям. Модули контента не знают про тарифы."""
    if not flags.is_enabled(flags.MONETIZATION_ENABLED, user):
        return True  # этап 1: всё бесплатно для всех
    if not user or not user.is_authenticated:
        return False
    if _has_active_grant(user, key):
        return True
    plan = effective_plan(user)
    return bool(plan) and PlanFeature.objects.filter(plan=plan, feature__key=key).exists()
