from django.contrib import admin

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
    search_fields = ("name", "short_name", "city")
    inlines = [FacultyInline, EmailDomainInline]


@admin.register(Specialty)
class SpecialtyAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "level")
    list_filter = ("level",)
    search_fields = ("code", "name")


@admin.register(UniversityRequest)
class UniversityRequestAdmin(admin.ModelAdmin):
    list_display = ("name", "city", "status", "created_at")
    list_filter = ("status",)
    raw_id_fields = ("user", "resolved_university")


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
