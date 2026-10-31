from django.contrib import admin

from apps.content.admin_editorial import EditorialAdmin, EditorialLockMixin

from .models import AnswerOption, Question, Quiz, QuizAttempt, QuizQuestion


class AnswerOptionInline(EditorialLockMixin, admin.TabularInline):
    model = AnswerOption
    extra = 0


@admin.register(Question)
class QuestionAdmin(EditorialAdmin):
    discipline_lookup = "topic__discipline"
    list_display = (
        "__str__",
        "topic",
        "kind",
        "difficulty",
        "status",
        "reviewer",
    )
    list_filter = ("kind", "difficulty", "topic__discipline")
    raw_id_fields = ("topic",)
    inlines = [AnswerOptionInline]


class QuizQuestionInline(admin.TabularInline):
    model = QuizQuestion
    extra = 0
    raw_id_fields = ("question",)


@admin.register(Quiz)
class QuizAdmin(admin.ModelAdmin):
    list_display = ("title", "discipline", "topic", "mode", "status", "is_premium")
    list_filter = ("status", "mode", "discipline")
    raw_id_fields = ("topic",)
    inlines = [QuizQuestionInline]


@admin.register(QuizAttempt)
class QuizAttemptAdmin(admin.ModelAdmin):
    list_display = ("id", "quiz", "mode", "status", "score", "flagged", "started_at")
    list_filter = ("status", "mode", "flagged")
    raw_id_fields = ("user", "quiz", "discipline")
