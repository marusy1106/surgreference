from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import Consent, DataSubjectRequest, User, UserSession


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ("-created_at",)
    list_display = (
        "display_name",
        "email",
        "is_verified",
        "trust_status",
        "founder_number",
        "is_staff",
        "created_at",
    )
    list_filter = ("is_staff", "is_active", "trust_status", "leaderboard_opt_in")
    search_fields = ("email", "display_name")
    readonly_fields = (
        "created_at",
        "updated_at",
        "last_login",
        "deleted_at",
        "founder_number",
    )
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        (
            "Профиль",
            {
                "fields": (
                    "display_name",
                    "first_name",
                    "email_verified_at",
                    "leaderboard_opt_in",
                )
            },
        ),
        (
            "Статус",
            {"fields": ("is_active", "trust_status", "founder_number", "deleted_at")},
        ),
        (
            "Права",
            {"fields": ("is_staff", "is_superuser", "groups", "user_permissions")},
        ),
        ("Даты", {"fields": ("last_login", "created_at", "updated_at")}),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("email", "display_name", "password1", "password2"),
            },
        ),
    )

    @admin.display(boolean=True, description="email подтверждён")
    def is_verified(self, obj):
        return obj.is_verified


@admin.register(UserSession)
class UserSessionAdmin(admin.ModelAdmin):
    list_display = ("user", "platform", "device_name", "last_used_at", "revoked_at")
    list_filter = ("platform",)
    exclude = ("refresh_token_hash",)
    raw_id_fields = ("user",)


@admin.register(Consent)
class ConsentAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "document",
        "document_version",
        "accepted_at",
        "withdrawn_at",
    )
    list_filter = ("document", "document_version")
    raw_id_fields = ("user",)


@admin.register(DataSubjectRequest)
class DataSubjectRequestAdmin(admin.ModelAdmin):
    list_display = ("kind", "status", "received_at", "due_at", "completed_at")
    list_filter = ("kind", "status")
    raw_id_fields = ("user", "handled_by")
