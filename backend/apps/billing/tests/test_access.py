from datetime import timedelta

import pytest
from django.utils import timezone

from apps.billing import flags
from apps.billing.models import EntitlementGrant, Feature, FeatureFlag, Plan, Subscription
from apps.billing.selectors import has_feature

pytestmark = pytest.mark.django_db


def enable_monetization():
    FeatureFlag.objects.filter(key=flags.MONETIZATION_ENABLED).update(enabled=True)
    flags.invalidate_cache()


def test_seeded_plans_and_flags():
    assert set(Plan.objects.values_list("code", flat=True)) == {"free", "premium"}
    assert flags.is_enabled(flags.MONETIZATION_ENABLED) is False
    assert flags.is_enabled(flags.CASES_ENABLED) is True


def test_stage_one_everything_is_free(make_user):
    assert has_feature(make_user(), "catalog.full")
    assert has_feature(make_user(), "analytics.advanced")


def test_free_plan_lacks_premium_feature_when_monetized(make_user):
    enable_monetization()
    user = make_user()
    assert not has_feature(user, "catalog.full")
    assert has_feature(user, "cases.access")  # у Free есть с лимитом


def test_active_subscription_grants_premium(make_user):
    enable_monetization()
    user = make_user()
    Subscription.objects.create(
        user=user,
        plan=Plan.objects.get(code="premium"),
        store="app_store",
        status=Subscription.Status.ACTIVE,
        current_period_end=timezone.now() + timedelta(days=30),
    )
    assert has_feature(user, "catalog.full")


def test_expired_subscription_does_not_grant(make_user):
    enable_monetization()
    user = make_user()
    Subscription.objects.create(
        user=user,
        plan=Plan.objects.get(code="premium"),
        store="rustore",
        status=Subscription.Status.ACTIVE,
        current_period_end=timezone.now() - timedelta(minutes=1),
    )
    assert not has_feature(user, "catalog.full")


def test_founder_grant_gives_premium(make_user):
    enable_monetization()
    user = make_user()
    EntitlementGrant.objects.create(user=user, plan=Plan.objects.get(code="premium"), reason="founder")
    assert has_feature(user, "analytics.advanced")


def test_expired_feature_grant_ignored(make_user):
    enable_monetization()
    user = make_user()
    EntitlementGrant.objects.create(
        user=user,
        feature=Feature.objects.get(key="catalog.full"),
        reason="promo",
        expires_at=timezone.now() - timedelta(days=1),
    )
    assert not has_feature(user, "catalog.full")


def test_staff_only_rule(make_user):
    FeatureFlag.objects.create(key="beta", enabled=True, description="", rules={"staff_only": True})
    assert not flags.is_enabled("beta", make_user())
    assert flags.is_enabled("beta", make_user(is_staff=True))


def test_rollout_is_stable_per_user(make_user):
    FeatureFlag.objects.create(key="half", enabled=True, description="", rollout_percent=50)
    users = [make_user() for _ in range(40)]
    first = [flags.is_enabled("half", u) for u in users]
    assert first == [flags.is_enabled("half", u) for u in users]
    assert 0 < sum(first) < len(users)
