from django.contrib import admin, messages

from . import services
from .models import (
    EducationProfile,
    Faculty,
    Specialty,
    University,
    UniversityEmailDomain,
    UniversityRequest,
)


class FacultyInline(admin.TabularInline):
    model = Faculty
    extra = 0


class EmailDomainInline(admin.TabularInline):
    model = UniversityEmailDomain
    extra = 0


@admin.register(University)
class UniversityAdmin(admin.ModelAdmin):
    list_display = ("name", "short_name", "city", "is_active")
    list_filter = ("is_active", "region")
    search_fields = ("name", "short_name", "aliases", "city")
    inlines = [FacultyInline, EmailDomainInline]


@admin.register(Specialty)
class SpecialtyAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "level")
    list_filter = ("level",)
    search_fields = ("code", "name")


@admin.register(UniversityRequest)
class UniversityRequestAdmin(admin.ModelAdmin):
    list_display = ("name", "city", "status", "resolved_university", "created_at")
    list_filter = ("status",)
    raw_id_fields = ("user", "resolved_university")
    actions = ["approve", "merge", "reject"]

    def _new(self, queryset):
        return queryset.filter(status=UniversityRequest.Status.NEW)

    @admin.action(description="Одобрить: создать вуз из заявки")
    def approve(self, request, queryset):
        for item in self._new(queryset):
            services.approve_request(item)
        self.message_user(request, "Вузы созданы и подставлены в профили. Проверьте название и город.")

    @admin.action(description="Объединить с вузом из поля «resolved university»")
    def merge(self, request, queryset):
        for item in self._new(queryset):
            if item.resolved_university is None:
                self.message_user(request, f"«{item.name}»: сначала выберите вуз", messages.WARNING)
                continue
            services.resolve_request(item, item.resolved_university, UniversityRequest.Status.MERGED)

    @admin.action(description="Отклонить")
    def reject(self, request, queryset):
        for item in self._new(queryset):
            services.reject_request(item)


@admin.register(EducationProfile)
class EducationProfileAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "status",
        "university",
        "course",
        "study_year",
        "verification_status",
    )
    list_filter = ("status", "verification_status")
    raw_id_fields = ("user", "university", "faculty", "specialty")
