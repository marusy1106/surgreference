from django.contrib import admin

from .models import AdminAuditLog, SecurityEvent


class ReadOnlyAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(SecurityEvent)
class SecurityEventAdmin(ReadOnlyAdmin):
    list_display = ("occurred_at", "event", "outcome", "actor", "subject", "ip")
    list_filter = ("event", "outcome")


@admin.register(AdminAuditLog)
class AdminAuditLogAdmin(ReadOnlyAdmin):
    list_display = ("occurred_at", "staff_user", "action", "model", "object_id")
    list_filter = ("action", "model")
