from django.contrib import admin, messages
from django.db.models import Max
from django.urls import reverse
from django.utils.html import format_html

from . import editorial, references
from .admin_editorial import EditorialAdmin
from .models import (
    ClinicalGuideline,
    ContentRecheck,
    ContentReview,
    Discipline,
    GuidelineVersion,
    ICD10Code,
    Lesson,
    LessonRevision,
    MediaAsset,
    Source,
    Topic,
)


@admin.register(Discipline)
class DisciplineAdmin(admin.ModelAdmin):
    list_display = ("title", "slug", "status", "is_premium", "sort_order")
    list_filter = ("status", "is_premium")
    prepopulated_fields = {"slug": ("title",)}
    filter_horizontal = ("reviewers",)

    def formfield_for_manytomany(self, db_field, request, **kwargs):
        if db_field.name == "reviewers":
            kwargs["queryset"] = db_field.related_model.objects.filter(
                is_active=True, groups__name="medical_reviewer"
            ).distinct()
        return super().formfield_for_manytomany(db_field, request, **kwargs)


@admin.register(Topic)
class TopicAdmin(admin.ModelAdmin):
    list_display = ("title", "discipline", "status", "is_premium", "sort_order")
    list_filter = ("discipline", "status")
    prepopulated_fields = {"slug": ("title",)}


class LessonRevisionInline(admin.TabularInline):
    model = LessonRevision
    fk_name = "lesson"
    fields = ("version", "title", "status", "author", "reviewer", "published_at")
    readonly_fields = fields
    extra = 0
    can_delete = False
    show_change_link = True


@admin.register(Lesson)
class LessonAdmin(admin.ModelAdmin):
    list_display = ("__str__", "topic", "is_premium", "sort_order")
    list_filter = ("topic__discipline",)
    # Опубликованную ревизию переключает только публикация (content.editorial).
    readonly_fields = ("published_revision",)
    inlines = [LessonRevisionInline]


@admin.register(LessonRevision)
class LessonRevisionAdmin(EditorialAdmin):
    discipline_lookup = "lesson__topic__discipline"
    list_display = ("title", "lesson", "version", "status", "author", "reviewer", "published_at")
    list_filter = ("lesson__topic__discipline",)
    raw_id_fields = ("lesson",)
    search_fields = ("title",)

    def save_model(self, request, obj, form, change):
        if not change:
            last = LessonRevision.objects.filter(lesson=obj.lesson).aggregate(v=Max("version"))["v"]
            obj.version = (last or 0) + 1
        super().save_model(request, obj, form, change)


@admin.register(Source)
class SourceAdmin(admin.ModelAdmin):
    list_display = ("title", "kind", "license", "rights_expires_at")
    list_filter = ("kind", "license")
    search_fields = ("title", "authors")


@admin.register(ContentReview)
class ContentReviewAdmin(admin.ModelAdmin):
    """Журнал только для чтения: записи создаёт content.editorial."""

    list_display = ("content_type", "object_id", "reviewer", "decision", "created_at")
    list_filter = ("decision", "content_type")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(ICD10Code)
class ICD10CodeAdmin(admin.ModelAdmin):
    list_display = ("code", "title", "is_leaf")
    search_fields = ("code", "title")
    raw_id_fields = ("parent",)


class GuidelineVersionInline(admin.TabularInline):
    model = GuidelineVersion
    fk_name = "guideline"
    extra = 0
    fields = (
        "version_label",
        "approved_at",
        "revision_due",
        "source_url",
        "checked_by",
        "checked_at",
    )
    raw_id_fields = ("checked_by",)


@admin.register(ClinicalGuideline)
class ClinicalGuidelineAdmin(admin.ModelAdmin):
    list_display = ("title", "rubricator_id", "age_group", "status")
    list_filter = ("status", "age_group")
    search_fields = ("title", "rubricator_id")
    # Текущую версию переключает действие «Сделать текущей» в версиях КР: оно же ставит уроки на перепроверку.
    readonly_fields = ("current_version",)
    inlines = [GuidelineVersionInline]


@admin.register(GuidelineVersion)
class GuidelineVersionAdmin(admin.ModelAdmin):
    list_display = ("guideline", "version_label", "approved_at", "revision_due", "is_current", "checked_by")
    list_filter = ("guideline__status",)
    search_fields = ("guideline__title", "version_label")
    raw_id_fields = ("guideline",)
    readonly_fields = ("checked_by", "checked_at", "superseded_by")
    actions = ["make_current"]

    @admin.display(boolean=True, description="текущая")
    def is_current(self, obj):
        return obj.guideline.current_version_id == obj.pk

    @admin.action(description="Сделать текущей версией (уроки со ссылкой — на перепроверку)")
    def make_current(self, request, queryset):
        if not editorial.is_chief_editor(request.user):
            self.message_user(request, "Текущую версию КР выбирает главный редактор", messages.ERROR)
            return
        if queryset.values("guideline").distinct().count() != queryset.count():
            self.message_user(request, "Выберите не больше одной версии каждой КР", messages.ERROR)
            return
        for version in queryset.select_related("guideline"):
            queued = references.set_current_version(version.guideline, version, request.user)
            self.message_user(request, f"«{version}» — текущая; на перепроверку: {queued}")


@admin.register(ContentRecheck)
class ContentRecheckAdmin(admin.ModelAdmin):
    """Записи создаёт references (новая версия или срок пересмотра КР). Редактор открывает урок,
    при необходимости создаёт новую версию и отмечает перепроверку выполненной."""

    list_display = ("content_link", "guideline", "reason", "created_at", "resolved_at", "resolved_by")
    list_filter = (("resolved_at", admin.EmptyFieldListFilter), "guideline")
    actions = ["resolve"]

    @admin.display(description="контент")
    def content_link(self, obj):
        meta = obj.content_type.model_class()._meta
        url = reverse(f"admin:{meta.app_label}_{meta.model_name}_change", args=[obj.object_id])
        return format_html('<a href="{}">{}</a>', url, obj.content_object or obj.object_id)

    @admin.action(description="Отметить проверенным", permissions=["change"])
    def resolve(self, request, queryset):
        done = references.resolve_rechecks(queryset, request.user)
        self.message_user(request, f"Отмечено проверенными: {done}")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        # Список и действие «Отметить проверенным»; сама запись не правится.
        return obj is None and super().has_change_permission(request, obj)

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(MediaAsset)
class MediaAssetAdmin(admin.ModelAdmin):
    list_display = ("s3_key", "mime", "status", "uploaded_by", "created_at")
    list_filter = ("status", "mime")
    raw_id_fields = ("source", "uploaded_by")
