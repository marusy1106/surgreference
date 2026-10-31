from django.conf import settings
from django.db import models
from django.db.models import Q
from django.utils import timezone

from apps.core.models import TimeStampedModel, UUIDModel, choices_check, range_check


class Store(models.TextChoices):
    APP_STORE = "app_store", "App Store"
    RUSTORE = "rustore", "RuStore"


class Plan(TimeStampedModel):
    FREE = "free"
    PREMIUM = "premium"

    code = models.SlugField(max_length=32, unique=True)
    title = models.CharField(max_length=64)
    is_active = models.BooleanField(default=True)
    features = models.ManyToManyField("Feature", through="PlanFeature", related_name="plans")

    class Meta:
        verbose_name = "тариф"
        verbose_name_plural = "тарифы"

    def __str__(self):
        return self.title


class Feature(TimeStampedModel):
    key = models.CharField(max_length=64, unique=True, help_text="Напр. cases.full")
    description = models.CharField(max_length=255)

    class Meta:
        verbose_name = "функция"
        verbose_name_plural = "функции"

    def __str__(self):
        return self.key


class PlanFeature(models.Model):
    plan = models.ForeignKey(Plan, on_delete=models.CASCADE)
    feature = models.ForeignKey(Feature, on_delete=models.CASCADE)
    limit_value = models.PositiveIntegerField(null=True, blank=True, help_text="Пусто — без ограничения")

    class Meta:
        constraints = [models.UniqueConstraint(fields=["plan", "feature"], name="billing_planfeature_uniq")]


class StoreProductPeriod(models.TextChoices):
    MONTH = "month", "месяц"
    YEAR = "year", "год"


class StoreProduct(TimeStampedModel):
    Period = StoreProductPeriod

    plan = models.ForeignKey(Plan, on_delete=models.PROTECT, related_name="products")
    store = models.CharField(max_length=16, choices=Store)
    product_id = models.CharField(max_length=128)
    period = models.CharField(max_length=8, choices=Period)
    trial_days = models.PositiveSmallIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        constraints = [
            choices_check("store", Store),
            choices_check("period", StoreProductPeriod),
            models.UniqueConstraint(fields=["store", "product_id"], name="billing_storeproduct_uniq"),
        ]


class SubscriptionStatus(models.TextChoices):
    TRIAL = "trial", "пробный период"
    ACTIVE = "active", "активна"
    GRACE = "grace", "льготный период"
    EXPIRED = "expired", "истекла"
    CANCELED = "canceled", "отменена"
    REFUNDED = "refunded", "возврат"


class Subscription(UUIDModel):
    Status = SubscriptionStatus

    ENTITLED_STATUSES = (Status.TRIAL, Status.ACTIVE, Status.GRACE)

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="subscriptions")
    plan = models.ForeignKey(Plan, on_delete=models.PROTECT, related_name="+")
    store_product = models.ForeignKey(StoreProduct, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    store = models.CharField(max_length=16, choices=Store)
    status = models.CharField(max_length=16, choices=Status)
    started_at = models.DateTimeField(default=timezone.now)
    current_period_end = models.DateTimeField()
    original_transaction_id = models.CharField(max_length=128, blank=True)
    auto_renew = models.BooleanField(default=True)
    offer_code = models.CharField(max_length=64, blank=True)

    class Meta:
        verbose_name = "подписка"
        verbose_name_plural = "подписки"
        constraints = [
            choices_check("store", Store),
            choices_check("status", SubscriptionStatus),
        ]
        indexes = [models.Index(fields=["user", "status", "current_period_end"])]


class PaymentTransaction(UUIDModel):
    """Заполняется только после подключения StoreKit 2 / RuStore (этап монетизации)."""

    subscription = models.ForeignKey(Subscription, null=True, on_delete=models.PROTECT, related_name="transactions")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="+")
    store = models.CharField(max_length=16, choices=Store)
    store_transaction_id = models.CharField(max_length=128)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    currency = models.CharField(max_length=3)
    status = models.CharField(max_length=32)
    verified_at = models.DateTimeField(null=True, blank=True)
    raw_payload = models.JSONField(default=dict, blank=True)

    class Meta:
        constraints = [
            choices_check("store", Store),
            models.UniqueConstraint(
                fields=["store", "store_transaction_id"],
                name="billing_transaction_uniq",
            ),
        ]


class EntitlementGrantReason(models.TextChoices):
    FOUNDER = "founder", "первые 100 пользователей"
    STAFF = "staff", "сотрудник"
    PROMO = "promo", "промо"
    COMPENSATION = "compensation", "компенсация"


class EntitlementGrant(TimeStampedModel):
    """Доступ вне подписки: основатели, сотрудники, промо, компенсации."""

    Reason = EntitlementGrantReason

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="entitlement_grants",
    )
    plan = models.ForeignKey(Plan, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    feature = models.ForeignKey(Feature, null=True, blank=True, on_delete=models.PROTECT, related_name="+")
    reason = models.CharField(max_length=16, choices=Reason)
    starts_at = models.DateTimeField(default=timezone.now)
    expires_at = models.DateTimeField(null=True, blank=True)
    granted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )

    class Meta:
        constraints = [
            choices_check("reason", EntitlementGrantReason),
            models.CheckConstraint(
                condition=(Q(plan__isnull=False) & Q(feature__isnull=True))
                | (Q(plan__isnull=True) & Q(feature__isnull=False)),
                name="billing_grant_plan_xor_feature",
            ),
        ]


class FeatureFlag(models.Model):
    key = models.CharField(max_length=64, primary_key=True)
    enabled = models.BooleanField(default=False)
    description = models.CharField(max_length=255)
    is_public = models.BooleanField("отдавать клиенту", default=True)
    rollout_percent = models.PositiveSmallIntegerField(default=100)
    rules = models.JSONField(default=dict, blank=True, help_text='Напр. {"staff_only": true}')
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "feature flag"
        verbose_name_plural = "feature flags"
        constraints = [range_check("rollout_percent", 0, 100)]

    def __str__(self):
        return self.key

    def save(self, *args, **kwargs):
        from . import flags

        super().save(*args, **kwargs)
        flags.invalidate_cache()


class SystemMilestone(models.Model):
    key = models.CharField(max_length=64, primary_key=True)
    reached_at = models.DateTimeField()
    value = models.IntegerField()
    notified_at = models.DateTimeField(null=True, blank=True)
