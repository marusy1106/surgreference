from django.contrib import admin

from .models import AnswerOption, Question, Quiz, QuizAttempt, QuizQuestion


class AnswerOptionInline(admin.TabularInline):
    model = AnswerOption
    extra = 0


@admin.register(Question)
class QuestionAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "topic",
        "kind",
        "difficulty",
        "version",
        "status",
        "reviewer",
    )
    list_filter = ("status", "kind", "difficulty", "topic__discipline")
    raw_id_fields = ("topic", "author", "reviewer", "previous_version")
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
