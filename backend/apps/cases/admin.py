from django.contrib import admin

from .models import CaseAttempt, CaseChoice, CaseStep, ClinicalCase


class CaseStepInline(admin.StackedInline):
    model = CaseStep
    extra = 0
    show_change_link = True


@admin.register(ClinicalCase)
class ClinicalCaseAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "discipline",
        "difficulty",
        "version",
        "status",
        "synthetic_attested_by",
    )
    list_filter = ("status", "discipline")
    raw_id_fields = ("author", "reviewer", "synthetic_attested_by", "previous_version")
    inlines = [CaseStepInline]


class CaseChoiceInline(admin.TabularInline):
    model = CaseChoice
    fk_name = "step"
    extra = 0
    raw_id_fields = ("next_step",)


@admin.register(CaseStep)
class CaseStepAdmin(admin.ModelAdmin):
    list_display = ("case", "sort_order", "kind")
    inlines = [CaseChoiceInline]


@admin.register(CaseAttempt)
class CaseAttemptAdmin(admin.ModelAdmin):
    list_display = ("id", "case", "status", "score", "started_at")
    list_filter = ("status",)
    raw_id_fields = ("user", "case")
