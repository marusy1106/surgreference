from django.contrib import admin

from .models import DailyMetrics

# Панель «Аналитика MVP» с графиками — этап 6.


@admin.register(DailyMetrics)
class DailyMetricsAdmin(admin.ModelAdmin):
    list_display = (
        "date",
        "registered",
        "confirmed",
        "dau",
        "mau",
        "quizzes_finished",
        "avg_session_sec",
    )
