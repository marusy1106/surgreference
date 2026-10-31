from django.contrib.contenttypes.models import ContentType
from django.db.models import Prefetch
from django.shortcuts import get_object_or_404

from .models import CatalogStatus, ContentSource, Discipline, Lesson, ReviewStatus, Topic


def published_disciplines():
    return Discipline.objects.filter(status=CatalogStatus.PUBLISHED)


def published_discipline(slug):
    return get_object_or_404(published_disciplines(), slug=slug)


def published_topics(**filters):
    return Topic.objects.filter(status=CatalogStatus.PUBLISHED, discipline__status=CatalogStatus.PUBLISHED, **filters)


def published_lessons(**filters):
    """Уроки с опубликованной ревизией в опубликованной теме."""
    return (
        Lesson.objects.filter(
            published_revision__status=ReviewStatus.PUBLISHED,
            topic__status=CatalogStatus.PUBLISHED,
            topic__discipline__status=CatalogStatus.PUBLISHED,
            **filters,
        )
        .select_related("published_revision")
        .order_by("topic", "sort_order")
    )


def published_lesson(lesson_id):
    return get_object_or_404(
        published_lessons().select_related("topic__discipline", "published_revision__reviewer"),
        pk=lesson_id,
    )


def sources_for(obj):
    content_type = ContentType.objects.get_for_model(obj)
    return (
        ContentSource.objects.filter(content_type=content_type, object_id=obj.pk)
        .select_related("source")
        .order_by("pk")
    )


def disciplines_with_topics():
    return published_disciplines().prefetch_related(
        Prefetch("topics", queryset=published_topics().order_by("sort_order"), to_attr="published_topics")
    )
