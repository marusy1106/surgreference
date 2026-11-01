from rest_framework import serializers

from .models import Discipline
from .references import resolve_blocks


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
    body = serializers.SerializerMethodField()
    published_at = serializers.DateTimeField(source="published_revision.published_at")
    reviewer = serializers.SerializerMethodField()
    sources = serializers.SerializerMethodField()

    def get_body(self, lesson) -> list[dict]:
        revision = lesson.published_revision
        return resolve_blocks(revision.body, revision.published_at)

    def get_reviewer(self, lesson) -> str:
        reviewer = lesson.published_revision.reviewer
        return reviewer.first_name or reviewer.display_name

    def get_sources(self, lesson) -> list[str]:
        return [
            f"{usage.source.title}{f', {usage.locator}' if usage.locator else ''}" for usage in self.context["sources"]
        ]


# --- Справочники ----------------------------------------------------------------------


def icd_brief(code) -> dict:
    return {"code": code.code, "title": code.title, "is_leaf": code.is_leaf}


def guideline_brief(guideline) -> dict:
    version = guideline.current_version
    return {
        "id": guideline.pk,
        "title": guideline.title,
        "icd_codes": guideline.icd_codes,
        "age_group": guideline.age_group,
        "status": guideline.status,
        "version": version.version_label if version else "",
        "approved_at": version.approved_at if version else None,
        "revision_due": version.revision_due if version else None,
    }
