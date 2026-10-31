from django.conf import settings
from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType
from django.contrib.postgres.fields import ArrayField
from django.db import models
from django.db.models import F, Q

from apps.core.models import TimeStampedModel, choices_check


class ReviewStatus(models.TextChoices):
    DRAFT = "draft", "черновик"
    IN_REVIEW = "in_review", "на проверке"
    CHANGES_REQUESTED = "changes_requested", "нужны правки"
    APPROVED = "approved", "одобрено"
    PUBLISHED = "published", "опубликовано"
    ARCHIVED = "archived", "в архиве"


class CatalogStatus(models.TextChoices):
    """Статус узлов каталога (дисциплина, тема, тест) — без медицинской проверки."""

    DRAFT = "draft", "черновик"
    PUBLISHED = "published", "опубликовано"
    ARCHIVED = "archived", "в архиве"


class ReviewedContent(TimeStampedModel):
    """Единица контента, проходящая медицинскую проверку.

    Опубликованная версия неизменяема: правка = новая версия, старая уходит в архив.
    """

    status = models.CharField(max_length=24, choices=ReviewStatus, default=ReviewStatus.DRAFT)
    author = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="+")
    reviewer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="+",
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    published_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        abstract = True


def reviewed_content_constraints():
    return [
        choices_check("status", ReviewStatus),
        models.CheckConstraint(
            condition=Q(reviewer__isnull=True) | ~Q(reviewer=F("author")),
            name="%(app_label)s_%(class)s_reviewer_not_author",
        ),
        models.CheckConstraint(
            condition=~Q(status__in=[ReviewStatus.APPROVED, ReviewStatus.PUBLISHED]) | Q(reviewer__isnull=False),
            name="%(app_label)s_%(class)s_approved_has_reviewer",
        ),
        models.CheckConstraint(
            condition=~Q(status=ReviewStatus.PUBLISHED) | Q(published_at__isnull=False),
            name="%(app_label)s_%(class)s_published_has_date",
        ),
    ]


class SourceKind(models.TextChoices):
    CLINICAL_GUIDELINE = "clinical_guideline", "клиническая рекомендация"
    TEXTBOOK = "textbook", "учебник"
    ARTICLE = "article", "статья"
    OWN = "own", "собственный материал"
    OTHER = "other", "другое"


class SourceLicense(models.TextChoices):
    OWN = "own", "собственный"
    LICENSED = "licensed", "по лицензионному договору"
    CC_BY = "cc_by", "CC BY"
    CC_BY_SA = "cc_by_sa", "CC BY-SA"
    PUBLIC_DOMAIN = "public_domain", "общественное достояние"
    CITATION = "citation", "цитирование (ст. 1274 ГК РФ)"
    PERMISSION = "permission", "письменное разрешение"


class Source(TimeStampedModel):
    Kind = SourceKind

    License = SourceLicense

    title = models.CharField(max_length=500)
    kind = models.CharField(max_length=32, choices=Kind)
    authors = models.CharField(max_length=500, blank=True)
    publisher = models.CharField(max_length=255, blank=True)
    year = models.PositiveSmallIntegerField(null=True, blank=True)
    url = models.URLField(max_length=1000, blank=True)
    license = models.CharField(max_length=32, choices=License)
    rights_document_key = models.CharField("документ о правах (S3)", max_length=500, blank=True)
    rights_expires_at = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)

    class Meta:
        verbose_name = "источник"
        verbose_name_plural = "источники"
        constraints = [
            choices_check("kind", SourceKind),
            choices_check("license", SourceLicense),
        ]

    def __str__(self):
        return self.title


class Discipline(TimeStampedModel):
    slug = models.SlugField(max_length=64, unique=True)
    title = models.CharField(max_length=128)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=64, blank=True)
    palette_token = models.CharField("аура (токен палитры)", max_length=32, default="surgery")
    sort_order = models.PositiveIntegerField(default=0)
    status = models.CharField(max_length=16, choices=CatalogStatus, default=CatalogStatus.DRAFT)
    is_premium = models.BooleanField(default=False)

    class Meta:
        verbose_name = "дисциплина"
        verbose_name_plural = "дисциплины"
        ordering = ["sort_order", "title"]
        constraints = [choices_check("status", CatalogStatus)]

    def __str__(self):
        return self.title


class Topic(TimeStampedModel):
    discipline = models.ForeignKey(Discipline, on_delete=models.PROTECT, related_name="topics")
    slug = models.SlugField(max_length=64)
    title = models.CharField(max_length=255)
    sort_order = models.PositiveIntegerField(default=0)
    status = models.CharField(max_length=16, choices=CatalogStatus, default=CatalogStatus.DRAFT)
    is_premium = models.BooleanField(default=False)

    class Meta:
        verbose_name = "тема"
        verbose_name_plural = "темы"
        ordering = ["discipline", "sort_order"]
        constraints = [
            choices_check("status", CatalogStatus),
            models.UniqueConstraint(fields=["discipline", "slug"], name="content_topic_discipline_slug_uniq"),
        ]

    def __str__(self):
        return self.title


class Lesson(TimeStampedModel):
    topic = models.ForeignKey(Topic, on_delete=models.PROTECT, related_name="lessons")
    slug = models.SlugField(max_length=64)
    sort_order = models.PositiveIntegerField(default=0)
    published_revision = models.ForeignKey(
        "LessonRevision",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    is_premium = models.BooleanField(default=False)

    class Meta:
        verbose_name = "урок"
        verbose_name_plural = "уроки"
        ordering = ["topic", "sort_order"]
        constraints = [models.UniqueConstraint(fields=["topic", "slug"], name="content_lesson_topic_slug_uniq")]

    def __str__(self):
        return self.published_revision.title if self.published_revision_id else self.slug


class LessonRevision(ReviewedContent):
    """Версия урока. body — массив типизированных блоков (heading, paragraph, list, table, image,
    callout, icd_ref, guideline_ref), а не HTML."""

    lesson = models.ForeignKey(Lesson, on_delete=models.PROTECT, related_name="revisions")
    version = models.PositiveIntegerField()
    title = models.CharField(max_length=255)
    body = models.JSONField(default=list)
    estimated_minutes = models.PositiveSmallIntegerField(default=5)
    change_summary = models.TextField("что изменено", blank=True)
    publisher = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="+",
    )

    class Meta:
        verbose_name = "ревизия урока"
        verbose_name_plural = "ревизии уроков"
        constraints = [
            *reviewed_content_constraints(),
            models.UniqueConstraint(fields=["lesson", "version"], name="content_lessonrevision_version_uniq"),
            models.UniqueConstraint(
                fields=["lesson"],
                condition=Q(status=ReviewStatus.PUBLISHED),
                name="content_lessonrevision_one_published",
            ),
        ]

    def __str__(self):
        return f"{self.title} v{self.version}"


class ContentReviewDecision(models.TextChoices):
    APPROVE = "approve", "одобрить"
    REQUEST_CHANGES = "request_changes", "вернуть на доработку"
    REJECT = "reject", "отклонить"


class ContentReview(models.Model):
    """История решений рецензентов по любой единице контента."""

    Decision = ContentReviewDecision

    content_type = models.ForeignKey(ContentType, on_delete=models.PROTECT)
    object_id = models.PositiveBigIntegerField()
    content_object = GenericForeignKey("content_type", "object_id")
    reviewer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="+")
    decision = models.CharField(max_length=24, choices=Decision)
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "решение рецензента"
        verbose_name_plural = "решения рецензентов"
        constraints = [choices_check("decision", ContentReviewDecision)]
        indexes = [models.Index(fields=["content_type", "object_id"])]


class ContentSource(models.Model):
    """Связь единицы контента с источником."""

    content_type = models.ForeignKey(ContentType, on_delete=models.CASCADE)
    object_id = models.PositiveBigIntegerField()
    content_object = GenericForeignKey("content_type", "object_id")
    source = models.ForeignKey(Source, on_delete=models.PROTECT, related_name="usages")
    locator = models.CharField("страница / раздел", max_length=255, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["content_type", "object_id", "source", "locator"],
                name="content_contentsource_uniq",
            )
        ]
        indexes = [models.Index(fields=["content_type", "object_id"])]


class ICD10Code(models.Model):
    code = models.CharField(max_length=8, primary_key=True)
    parent = models.ForeignKey("self", null=True, blank=True, on_delete=models.PROTECT, related_name="children")
    title = models.CharField(max_length=500)
    chapter = models.CharField(max_length=16, blank=True)
    block = models.CharField(max_length=16, blank=True)
    is_leaf = models.BooleanField(default=True)
    nsi_version = models.CharField("версия импорта НСИ", max_length=32)

    class Meta:
        verbose_name = "код МКБ-10"
        verbose_name_plural = "МКБ-10"
        ordering = ["code"]

    def __str__(self):
        return f"{self.code} {self.title}"


class ClinicalGuidelineAgeGroup(models.TextChoices):
    ADULTS = "adults", "взрослые"
    CHILDREN = "children", "дети"
    ALL = "all", "взрослые и дети"


class ClinicalGuidelineStatus(models.TextChoices):
    ACTIVE = "active", "действует"
    UNDER_REVISION = "under_revision", "на пересмотре"
    SUPERSEDED = "superseded", "заменена"
    WITHDRAWN = "withdrawn", "отменена"


class ClinicalGuideline(TimeStampedModel):
    AgeGroup = ClinicalGuidelineAgeGroup

    Status = ClinicalGuidelineStatus

    rubricator_id = models.CharField("ID в рубрикаторе КР", max_length=32, unique=True, null=True, blank=True)
    title = models.CharField(max_length=500)
    icd_codes = ArrayField(models.CharField(max_length=8), default=list, blank=True)
    age_group = models.CharField(max_length=16, choices=AgeGroup)
    developer = models.CharField("разработчик", max_length=500, blank=True)
    status = models.CharField(max_length=16, choices=Status, default=Status.ACTIVE)
    current_version = models.ForeignKey(
        "GuidelineVersion",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )

    class Meta:
        verbose_name = "клиническая рекомендация"
        verbose_name_plural = "клинические рекомендации"
        constraints = [
            choices_check("age_group", ClinicalGuidelineAgeGroup),
            choices_check("status", ClinicalGuidelineStatus),
        ]

    def __str__(self):
        return self.title


class GuidelineVersion(TimeStampedModel):
    guideline = models.ForeignKey(ClinicalGuideline, on_delete=models.PROTECT, related_name="versions")
    version_label = models.CharField(max_length=32)
    approved_at = models.DateField()
    effective_from = models.DateField(null=True, blank=True)
    revision_due = models.DateField("плановый пересмотр", null=True, blank=True)
    summary = models.JSONField(default=list, blank=True)
    source_url = models.URLField(max_length=1000)
    file_key = models.CharField(max_length=500, blank=True)
    checked_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="+",
    )
    checked_at = models.DateTimeField(null=True, blank=True)
    superseded_by = models.ForeignKey("self", null=True, blank=True, on_delete=models.SET_NULL, related_name="+")

    class Meta:
        verbose_name = "версия КР"
        verbose_name_plural = "версии КР"
        constraints = [
            models.UniqueConstraint(
                fields=["guideline", "version_label"],
                name="content_guidelineversion_uniq",
            )
        ]

    def __str__(self):
        return f"{self.guideline} ({self.version_label})"


class MediaAssetStatus(models.TextChoices):
    PENDING = "pending", "на проверке"
    APPROVED = "approved", "одобрено"
    REJECTED = "rejected", "отклонено"


class MediaAsset(TimeStampedModel):
    Status = MediaAssetStatus

    s3_key = models.CharField(max_length=500, unique=True)
    mime = models.CharField(max_length=64)
    size_bytes = models.PositiveIntegerField()
    sha256 = models.CharField(max_length=64)
    width = models.PositiveIntegerField(null=True, blank=True)
    height = models.PositiveIntegerField(null=True, blank=True)
    alt_text = models.CharField("описание для скринридера", max_length=500)
    source = models.ForeignKey(Source, null=True, blank=True, on_delete=models.PROTECT)
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="+")
    status = models.CharField(max_length=16, choices=Status, default=Status.PENDING)

    class Meta:
        verbose_name = "медиафайл"
        verbose_name_plural = "медиафайлы"
        constraints = [choices_check("status", MediaAssetStatus)]
