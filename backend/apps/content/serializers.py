from rest_framework import serializers

from .models import Discipline


class DisciplineSerializer(serializers.ModelSerializer):
    class Meta:
        model = Discipline
        fields = ("slug", "title", "description", "palette_token", "is_premium")


class LessonSerializer(serializers.Serializer):
    """Опубликованная ревизия урока. body — типизированные блоки (docs/05-learning.md, 5.1)."""

    id = serializers.IntegerField(source="pk")
    topic_id = serializers.IntegerField()
    topic = serializers.CharField(source="topic.title")
    discipline = serializers.CharField(source="topic.discipline.title")
    discipline_slug = serializers.CharField(source="topic.discipline.slug")
    title = serializers.CharField(source="published_revision.title")
    version = serializers.IntegerField(source="published_revision.version")
    estimated_minutes = serializers.IntegerField(source="published_revision.estimated_minutes")
    body = serializers.JSONField(source="published_revision.body")
    published_at = serializers.DateTimeField(source="published_revision.published_at")
    reviewer = serializers.SerializerMethodField()
    sources = serializers.SerializerMethodField()

    def get_reviewer(self, lesson) -> str:
        reviewer = lesson.published_revision.reviewer
        return reviewer.first_name or reviewer.display_name

    def get_sources(self, lesson) -> list[str]:
        return [
            f"{usage.source.title}{f', {usage.locator}' if usage.locator else ''}" for usage in self.context["sources"]
        ]
