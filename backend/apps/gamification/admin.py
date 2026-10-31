from django.contrib import admin

from .models import Achievement, XpEvent


@admin.register(Achievement)
class AchievementAdmin(admin.ModelAdmin):
    list_display = ("code", "title", "xp_reward", "is_hidden", "is_active")


@admin.register(XpEvent)
class XpEventAdmin(admin.ModelAdmin):
    list_display = ("user", "amount", "reason", "source_type", "created_at")
    list_filter = ("reason",)
    raw_id_fields = ("user", "university")
