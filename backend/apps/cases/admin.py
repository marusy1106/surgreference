from django.contrib import admin

from apps.content import editorial
from apps.content.admin_editorial import EditorialAdmin, EditorialLockMixin

from .models import CaseAttempt, CaseChoice, CaseStep, ClinicalCase


class CaseStepInline(EditorialLockMixin, admin.StackedInline):
    model = CaseStep
    extra = 0
    show_change_link = True


@admin.register(ClinicalCase)
class ClinicalCaseAdmin(EditorialAdmin):
    list_display = (
        "title",
        "discipline",
        "difficulty",
        "version",
        "status",
        "synthetic_attested_by",
    )
    list_filter = ("discipline",)
    inlines = [CaseStepInline]


class CaseChoiceInline(EditorialLockMixin, admin.TabularInline):
    model = CaseChoice
    fk_name = "step"
    extra = 0
    raw_id_fields = ("next_step",)

    def editorial_object(self, step):
        return step.case


@admin.register(CaseStep)
class CaseStepAdmin(admin.ModelAdmin):
    """Варианты шага правятся здесь — пока кейс в черновике или на доработке."""

    list_display = ("case", "sort_order", "kind")
    inlines = [CaseChoiceInline]

    def _editable(self, request, obj):
        return obj is None or editorial.can_edit(request.user, obj.case)

    def has_change_permission(self, request, obj=None):
        return super().has_change_permission(request, obj) and self._editable(request, obj)

    def has_delete_permission(self, request, obj=None):
        return super().has_delete_permission(request, obj) and self._editable(request, obj)


@admin.register(CaseAttempt)
class CaseAttemptAdmin(admin.ModelAdmin):
    list_display = ("id", "case", "status", "score", "started_at")
    list_filter = ("status",)
    raw_id_fields = ("user", "case")
