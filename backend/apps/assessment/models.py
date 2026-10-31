from django.conf import settings
from django.contrib.postgres.fields import ArrayField
from django.db import models
from django.db.models import Q
from django.utils import timezone

from apps.content.models import (
    CatalogStatus,
    ReviewedContent,
    ReviewStatus,
    reviewed_content_constraints,
)
from apps.core.models import TimeStampedModel, UUIDModel, choices_check, range_check


class QuestionKind(models.TextChoices):
    SINGLE = "single", "один ответ"
    MULTIPLE = "multiple", "несколько ответов"


class Question(ReviewedContent):
    Kind = QuestionKind

    topic = models.ForeignKey("content.Topic", on_delete=models.PROTECT, related_name="questions")
    kind = models.CharField(max_length=16, choices=Kind, default=Kind.SINGLE)
    stem = models.JSONField("условие (блоки)", default=list)
    explanation = models.TextField("общий разбор", blank=True)
    difficulty = models.PositiveSmallIntegerField(default=2)
    version = models.PositiveIntegerField(default=1)
    previous_version = models.ForeignKey(
        "self",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="next_versions",
    )
    is_premium = models.BooleanField(default=False)

    class Meta:
        verbose_name = "вопрос"
        verbose_name_plural = "вопросы"
        constraints = [
            *reviewed_content_constraints(),
            choices_check("kind", QuestionKind),
            range_check("difficulty", 1, 3),
        ]
        indexes = [models.Index(fields=["topic", "status"])]

    def __str__(self):
        text = (
            " ".join(b.get("text", "") for b in self.stem if isinstance(b, dict)) if isinstance(self.stem, list) else ""
        )
        return f"{text[:80] or 'Вопрос'} v{self.version}"

    def editorial_discipline_id(self):
        return self.topic.discipline_id

    def editorial_problems(self):
        problems = []
        if not any(isinstance(b, dict) and str(b.get("text", "")).strip() for b in self.stem or []):
            problems.append("Нет условия вопроса")
        options = list(self.options.all())
        correct = sum(o.is_correct for o in options)
        if len(options) < 2:
            problems.append("Нужно хотя бы два варианта ответа")
        if correct == 0:
            problems.append("Не отмечен правильный вариант")
        if self.kind == QuestionKind.SINGLE and correct > 1:
            problems.append("В вопросе с одним ответом отмечено несколько правильных")
        if any(not o.explanation.strip() for o in options):
            problems.append("У каждого варианта нужно объяснение, почему он верный или нет")
        return problems

    def editorial_previous(self):
        previous = self.previous_version
        return previous if previous and previous.status == ReviewStatus.PUBLISHED else None

    def editorial_on_published(self, previous):
        # Тесты, где был прежний вопрос, получают новую версию на то же место.
        if previous is not None:
            QuizQuestion.objects.filter(question=previous).update(question=self)

    def editorial_open_successor(self):
        return self.next_versions.exclude(status__in=[ReviewStatus.PUBLISHED, ReviewStatus.ARCHIVED]).first()

    def editorial_copy(self, author):
        copy = Question.objects.create(
            topic=self.topic,
            kind=self.kind,
            stem=self.stem,
            explanation=self.explanation,
            difficulty=self.difficulty,
            version=self.version + 1,
            previous_version=self,
            is_premium=self.is_premium,
            author=author,
        )
        AnswerOption.objects.bulk_create(
            AnswerOption(
                question=copy, text=o.text, is_correct=o.is_correct, explanation=o.explanation, sort_order=o.sort_order
            )
            for o in self.options.all()
        )
        return copy


class AnswerOption(models.Model):
    question = models.ForeignKey(Question, on_delete=models.CASCADE, related_name="options")
    text = models.TextField()
    is_correct = models.BooleanField(default=False)
    explanation = models.TextField("почему верно / неверно")
    sort_order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ["sort_order"]


class QuizMode(models.TextChoices):
    FIXED = "fixed", "фиксированный набор"
    RANDOM = "random", "случайные вопросы"


class Quiz(TimeStampedModel):
    Mode = QuizMode

    discipline = models.ForeignKey("content.Discipline", on_delete=models.PROTECT, related_name="quizzes")
    topic = models.ForeignKey(
        "content.Topic",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="quizzes",
    )
    title = models.CharField(max_length=255)
    mode = models.CharField(max_length=16, choices=Mode, default=Mode.FIXED)
    question_count = models.PositiveSmallIntegerField(default=10)
    time_limit_sec = models.PositiveIntegerField(null=True, blank=True)
    pass_threshold = models.DecimalField(max_digits=3, decimal_places=2, default=0.8)
    status = models.CharField(max_length=16, choices=CatalogStatus, default=CatalogStatus.DRAFT)
    is_premium = models.BooleanField(default=False)
    questions = models.ManyToManyField(Question, through="QuizQuestion", blank=True, related_name="+")

    class Meta:
        verbose_name = "тест"
        verbose_name_plural = "тесты"
        constraints = [
            choices_check("mode", QuizMode),
            choices_check("status", CatalogStatus),
            models.CheckConstraint(
                condition=Q(pass_threshold__gte=0) & Q(pass_threshold__lte=1),
                name="assessment_quiz_pass_threshold_range",
            ),
        ]

    def __str__(self):
        return self.title


class QuizQuestion(models.Model):
    quiz = models.ForeignKey(Quiz, on_delete=models.CASCADE)
    question = models.ForeignKey(Question, on_delete=models.PROTECT)
    sort_order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ["sort_order"]
        constraints = [models.UniqueConstraint(fields=["quiz", "question"], name="assessment_quizquestion_uniq")]


class QuizAttemptMode(models.TextChoices):
    TOPIC = "topic", "тест темы"
    TRAINING = "training", "тренировка"
    MISTAKES = "mistakes", "работа над ошибками"


class QuizAttemptStatus(models.TextChoices):
    IN_PROGRESS = "in_progress", "идёт"
    FINISHED = "finished", "завершена"
    ABANDONED = "abandoned", "брошена"


class QuizAttempt(UUIDModel):
    Mode = QuizAttemptMode

    Status = QuizAttemptStatus

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="quiz_attempts")
    quiz = models.ForeignKey(Quiz, null=True, blank=True, on_delete=models.PROTECT, related_name="attempts")
    discipline = models.ForeignKey("content.Discipline", on_delete=models.PROTECT, related_name="+")
    mode = models.CharField(max_length=16, choices=Mode)
    status = models.CharField(max_length=16, choices=Status, default=Status.IN_PROGRESS)
    started_at = models.DateTimeField(default=timezone.now)
    finished_at = models.DateTimeField(null=True, blank=True)
    correct_count = models.PositiveSmallIntegerField(default=0)
    total_count = models.PositiveSmallIntegerField(default=0)
    score = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    xp_awarded = models.IntegerField(default=0)
    flagged = models.BooleanField("подозрение на автоматизацию", default=False)

    class Meta:
        verbose_name = "попытка теста"
        verbose_name_plural = "попытки тестов"
        constraints = [
            choices_check("mode", QuizAttemptMode),
            choices_check("status", QuizAttemptStatus),
            models.CheckConstraint(
                condition=Q(correct_count__lte=models.F("total_count")),
                name="assessment_quizattempt_correct_lte_total",
            ),
            models.CheckConstraint(
                condition=~Q(status="finished") | Q(finished_at__isnull=False),
                name="assessment_quizattempt_finished_has_date",
            ),
        ]
        indexes = [
            models.Index(fields=["user", "-finished_at"]),
            models.Index(fields=["quiz", "user"]),
            models.Index(fields=["status", "started_at"]),
        ]


class AttemptAnswer(models.Model):
    """Строки создаются при старте попытки (фиксируют набор и порядок); ответ заполняется позже."""

    attempt = models.ForeignKey(QuizAttempt, on_delete=models.CASCADE, related_name="answers")
    question = models.ForeignKey(Question, on_delete=models.PROTECT, related_name="+")
    position = models.PositiveSmallIntegerField()
    option_order = ArrayField(models.BigIntegerField(), default=list)
    selected_option_ids = ArrayField(models.BigIntegerField(), default=list, blank=True)
    is_correct = models.BooleanField(null=True)
    time_spent_ms = models.PositiveIntegerField(null=True, blank=True)
    answered_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["position"]
        constraints = [
            models.UniqueConstraint(
                fields=["attempt", "question"],
                name="assessment_attemptanswer_question_uniq",
            ),
            models.UniqueConstraint(
                fields=["attempt", "position"],
                name="assessment_attemptanswer_position_uniq",
            ),
        ]
