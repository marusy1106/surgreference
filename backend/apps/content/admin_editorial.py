"""Админка для контента с медицинской проверкой: редактирование только в черновике, переходы —
на отдельной странице «Редакционный процесс» с журналом решений. Правила — в content.editorial."""

from django.contrib import admin, messages
from django.contrib.contenttypes.admin import GenericTabularInline
from django.core.exceptions import PermissionDenied
from django.shortcuts import get_object_or_404, redirect
from django.template.response import TemplateResponse
from django.urls import path, reverse

from . import editorial
from .models import ContentSource, Discipline, ReviewStatus

ACTION_LABELS = {
    "submit": "Отправить на проверку",
    "approve": "Одобрить",
    "request_changes": "Вернуть на доработку",
    "reject": "Отклонить",
    "publish": "Опубликовать",
    "withdraw": "Снять с публикации",
    "new_version": "Создать новую версию",
}

# Поля, которые меняет только процесс, а не форма.
PROCESS_FIELDS = (
    "status",
    "author",
    "reviewer",
    "reviewed_at",
    "published_at",
    "publisher",
    "version",
    "previous_version",
    "synthetic_attested_by",
)


class EditorialLockMixin:
    """Инлайны (варианты ответа, шаги, источники) правятся вместе с карточкой — и замораживаются с ней."""

    def editorial_object(self, obj):
        """Единица контента, чей статус решает, можно ли править (для вложенных — её владелец)."""
        return obj

    def _editable(self, request, obj):
        return obj is None or editorial.can_edit(request.user, self.editorial_object(obj))

    def has_add_permission(self, request, obj=None):
        return super().has_add_permission(request, obj) and self._editable(request, obj)

    def has_change_permission(self, request, obj=None):
        return super().has_change_permission(request, obj) and self._editable(request, obj)

    def has_delete_permission(self, request, obj=None):
        return super().has_delete_permission(request, obj) and self._editable(request, obj)


class SourceInline(EditorialLockMixin, GenericTabularInline):
    model = ContentSource
    extra = 0
    autocomplete_fields = ("source",)
    verbose_name = "источник"
    verbose_name_plural = "источники (без них на проверку не отправить)"


class QueueFilter(admin.SimpleListFilter):
    title = "очередь"
    parameter_name = "queue"

    def lookups(self, request, model_admin):
        return [
            ("mine", "Мои черновики и возвраты"),
            ("review", "Ждут моего решения"),
            ("publish", "Ждут публикации"),
        ]

    def queryset(self, request, queryset):
        user = request.user
        match self.value():
            case "mine":
                return queryset.filter(author=user, status__in=editorial.EDITABLE)
            case "review":
                disciplines = Discipline.objects.filter(reviewers=user)
                lookup = f"{self.model_admin_discipline_lookup}__in"
                return queryset.filter(status=ReviewStatus.IN_REVIEW, **{lookup: disciplines}).exclude(author=user)
            case "publish":
                return queryset.filter(status=ReviewStatus.APPROVED)
        return queryset


class EditorialAdmin(admin.ModelAdmin):
    """Путь от модели к дисциплине — для очереди рецензента (например, "topic__discipline")."""

    discipline_lookup = "discipline"
    change_form_template = "admin/content/editorial_change_form.html"

    def get_list_filter(self, request):
        queue = type("Queue", (QueueFilter,), {"model_admin_discipline_lookup": self.discipline_lookup})
        return [queue, "status", *super().get_list_filter(request)]

    def get_readonly_fields(self, request, obj=None):
        fields = {f.name for f in self.model._meta.get_fields() if getattr(f, "concrete", False)}
        if obj is not None and not editorial.can_edit(request.user, obj):
            # Опубликованное и отправленное на проверку не правится: только новая версия.
            return sorted(fields - {"id"})
        return [f for f in PROCESS_FIELDS if f in fields]

    def has_delete_permission(self, request, obj=None):
        # Удалить можно только черновик: всё, что прошло проверку, остаётся в истории (архив, журнал).
        allowed = super().has_delete_permission(request, obj)
        return allowed and (obj is None or obj.status == ReviewStatus.DRAFT)

    def get_actions(self, request):
        # Массовое удаление не смотрит на статус каждой записи — убираем.
        actions = super().get_actions(request)
        actions.pop("delete_selected", None)
        return actions

    def get_inlines(self, request, obj):
        return [*super().get_inlines(request, obj), SourceInline]

    def save_model(self, request, obj, form, change):
        if not change:
            obj.author = request.user
        super().save_model(request, obj, form, change)

    def get_urls(self):
        meta = self.model._meta
        return [
            path(
                "<path:object_id>/editorial/",
                self.admin_site.admin_view(self.editorial_view),
                name=f"{meta.app_label}_{meta.model_name}_editorial",
            ),
            *super().get_urls(),
        ]

    def editorial_view(self, request, object_id):
        obj = get_object_or_404(self.model, pk=object_id)
        if not self.has_view_permission(request, obj):
            raise PermissionDenied
        meta = self.model._meta
        if request.method == "POST":
            return self._run(request, obj, request.POST.get("action", ""))
        discipline = Discipline.objects.filter(pk=obj.editorial_discipline_id()).first()
        actions = editorial.allowed_actions(request.user, obj)
        context = {
            **self.admin_site.each_context(request),
            "opts": meta,
            "original": obj,
            "discipline": discipline,
            "reviewers": list(discipline.reviewers.all()) if discipline else [],
            "problems": editorial.problems(obj) if obj.status in editorial.EDITABLE else [],
            "actions": actions,
            "action_labels": [(a, ACTION_LABELS[a]) for a in actions],
            "history": editorial.history(obj),
            "changelist_url": f"admin:{meta.app_label}_{meta.model_name}_changelist",
            "title": "Редакционный процесс",
        }
        return TemplateResponse(request, "admin/content/editorial.html", context)

    def _run(self, request, obj, action):
        user, comment = request.user, request.POST.get("comment", "")
        meta = self.model._meta
        try:
            match action:
                case "submit":
                    editorial.submit(obj, user)
                case "approve" | "request_changes" | "reject":
                    attest = request.POST.get("attest_synthetic") == "1"
                    editorial.review(obj, user, action, comment, attest_synthetic=attest)
                case "publish":
                    editorial.publish(obj, user)
                case "withdraw":
                    editorial.withdraw(obj, user, comment)
                case "new_version":
                    copy = editorial.new_version(obj, user)
                    messages.success(request, f"Создан черновик «{copy}». Правьте его и отправляйте на проверку.")
                    return redirect(reverse(f"admin:{meta.app_label}_{meta.model_name}_change", args=[copy.pk]))
                case _:
                    raise editorial.EditorialError("Неизвестное действие")
        except editorial.EditorialError as e:
            messages.error(request, str(e))
        else:
            messages.success(request, f"{ACTION_LABELS[action]}: готово")
        return redirect(reverse(f"admin:{meta.app_label}_{meta.model_name}_editorial", args=[obj.pk]))
