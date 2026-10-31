from django.contrib import admin

from .models import (
    ClinicalGuideline,
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

# Полноценный редакционный интерфейс (переходы статусов, права ролей) — этап 5.


@admin.register(Discipline)
class DisciplineAdmin(admin.ModelAdmin):
    list_display = ("title", "slug", "status", "is_premium", "sort_order")
    list_filter = ("status", "is_premium")
    prepopulated_fields = {"slug": ("title",)}


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
    raw_id_fields = ("published_revision",)
    inlines = [LessonRevisionInline]


@admin.register(LessonRevision)
class LessonRevisionAdmin(admin.ModelAdmin):
    list_display = ("title", "version", "status", "author", "reviewer", "published_at")
    list_filter = ("status",)
    raw_id_fields = ("lesson", "author", "reviewer", "publisher")


@admin.register(Source)
class SourceAdmin(admin.ModelAdmin):
    list_display = ("title", "kind", "license", "rights_expires_at")
    list_filter = ("kind", "license")
    search_fields = ("title", "authors")


@admin.register(ContentReview)
class ContentReviewAdmin(admin.ModelAdmin):
    list_display = ("content_type", "object_id", "reviewer", "decision", "created_at")
    list_filter = ("decision", "content_type")


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
    raw_id_fields = ("current_version",)
    inlines = [GuidelineVersionInline]


@admin.register(MediaAsset)
class MediaAssetAdmin(admin.ModelAdmin):
    list_display = ("s3_key", "mime", "status", "uploaded_by", "created_at")
    list_filter = ("status", "mime")
    raw_id_fields = ("source", "uploaded_by")
