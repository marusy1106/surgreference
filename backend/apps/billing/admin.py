from django.contrib import admin

from .models import (
    EntitlementGrant,
    Feature,
    FeatureFlag,
    Plan,
    PlanFeature,
    StoreProduct,
    Subscription,
    SystemMilestone,
)


class PlanFeatureInline(admin.TabularInline):
    model = PlanFeature
    extra = 0


@admin.register(Plan)
class PlanAdmin(admin.ModelAdmin):
    list_display = ("code", "title", "is_active")
    inlines = [PlanFeatureInline]


@admin.register(Feature)
class FeatureAdmin(admin.ModelAdmin):
    list_display = ("key", "description")


@admin.register(StoreProduct)
class StoreProductAdmin(admin.ModelAdmin):
    list_display = ("product_id", "store", "plan", "period", "trial_days", "is_active")


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ("user", "plan", "store", "status", "current_period_end")
    list_filter = ("status", "store")
    raw_id_fields = ("user",)


@admin.register(EntitlementGrant)
class EntitlementGrantAdmin(admin.ModelAdmin):
    list_display = ("user", "plan", "feature", "reason", "starts_at", "expires_at")
    list_filter = ("reason",)
    raw_id_fields = ("user", "granted_by")


@admin.register(FeatureFlag)
class FeatureFlagAdmin(admin.ModelAdmin):
    list_display = (
        "key",
        "enabled",
        "rollout_percent",
        "is_public",
        "updated_by",
        "updated_at",
    )
    readonly_fields = ("updated_by", "updated_at")

    def save_model(self, request, obj, form, change):
        obj.updated_by = request.user
        super().save_model(request, obj, form, change)


@admin.register(SystemMilestone)
class SystemMilestoneAdmin(admin.ModelAdmin):
    list_display = ("key", "value", "reached_at", "notified_at")
