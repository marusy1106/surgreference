from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from apps.audit.services import record_security_event

from . import emails, services
from .models import Consent, DataSubjectRequest, User, UserSession

ROLE_FIELDS = ("is_staff", "is_superuser", "groups", "user_permissions")


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ("-created_at",)
    list_display = (
        "display_name",
        "email",
        "is_email_verified",
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

    actions = ["anonymize_users"]

    @admin.display(boolean=True, description="email подтверждён")
    def is_email_verified(self, obj):
        return obj.is_email_verified

    def get_readonly_fields(self, request, obj=None):
        # Роли и права выдаёт только superadmin (docs/04, 4.5).
        readonly = super().get_readonly_fields(request, obj)
        if not request.user.is_superuser:
            readonly = (*readonly, *ROLE_FIELDS)
        return readonly

    def has_delete_permission(self, request, obj=None):
        # Строки пользователей не удаляются: XP-журнал и аудит ссылаются на UUID. Вместо удаления — обезличивание.
        return False

    def save_related(self, request, form, formsets, change):
        before = self._roles(form.instance) if change else None
        super().save_related(request, form, formsets, change)
        after = self._roles(form.instance)
        if before != after:
            record_security_event(
                "admin.roles_changed",
                request=request,
                actor=request.user,
                subject=form.instance,
                before=before,
                after=after,
            )
            others = User.objects.filter(is_superuser=True, is_active=True).exclude(pk=request.user.pk)
            for superadmin in others:
                emails.roles_changed(superadmin.email, form.instance.display_name, request.user.display_name)

    @staticmethod
    def _roles(user):
        return {
            "is_staff": user.is_staff,
            "is_superuser": user.is_superuser,
            "groups": sorted(user.groups.values_list("name", flat=True)),
        }

    @admin.action(description="Обезличить выбранные аккаунты", permissions=["anonymize"])
    def anonymize_users(self, request, queryset):
        users = list(queryset.filter(deleted_at__isnull=True, is_superuser=False))
        for user in users:
            services.anonymize(user, note=f"по запросу, выполнил {request.user.display_name}")
            record_security_event("account.deleted", request=request, actor=request.user, subject=user)
        self.message_user(request, f"Обезличено аккаунтов: {len(users)}", messages.SUCCESS)

    def has_anonymize_permission(self, request):
        return request.user.is_superuser


@admin.register(UserSession)
class UserSessionAdmin(admin.ModelAdmin):
    list_display = ("user", "platform", "device_name", "last_used_at", "revoked_at")
    list_filter = ("platform",)
    exclude = ("refresh_token_hash", "previous_refresh_hash")
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
