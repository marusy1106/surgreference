from django.contrib import admin

from .models import Feedback


@admin.register(Feedback)
class FeedbackAdmin(admin.ModelAdmin):
    list_display = (
        "kind",
        "status",
        "screen",
        "rating",
        "platform",
        "app_version",
        "created_at",
    )
    list_filter = ("kind", "status", "platform")
    raw_id_fields = ("user", "handled_by")
    readonly_fields = (
        "user",
        "content_type",
        "object_id",
        "screen",
        "rating",
        "text",
        "app_version",
        "platform",
    )
