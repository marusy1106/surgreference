from drf_spectacular.utils import OpenApiParameter, OpenApiTypes, extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from . import references, selectors
from .models import ClinicalGuidelineStatus, ICD10Code
from .serializers import LessonSerializer, guideline_brief, icd_brief


class LessonView(APIView):
    @extend_schema(responses=LessonSerializer, tags=["learning"])
    def get(self, request, lesson_id):
        lesson = selectors.published_lesson(lesson_id)
        sources = selectors.sources_for(lesson.published_revision)
        return Response(LessonSerializer(lesson, context={"sources": sources}).data)


class ICD10ListView(APIView):
    @extend_schema(
        parameters=[OpenApiParameter("search", str, description="Код («K35», «к35.8») или слова из названия")],
        responses=OpenApiTypes.OBJECT,
        tags=["references"],
    )
    def get(self, request):
        """Без запроса — классы МКБ-10, с запросом — не больше 50 кодов."""
        rows = references.search_icd10(request.query_params.get("search", "")[:100])
        return Response([icd_brief(c) for c in rows])


class ICD10DetailView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT, tags=["references"])
    def get(self, request, code):
        item = references.icd10_code(code)
        children = ICD10Code.objects.filter(parent=item).order_by("code")
        return Response(
            {
                **icd_brief(item),
                "ancestors": [icd_brief(c) for c in references.ancestors(item)],
                "children": [icd_brief(c) for c in children],
                "guidelines": [guideline_brief(g) for g in references.guidelines_for_code(item.code)],
            }
        )


class GuidelineListView(APIView):
    @extend_schema(
        parameters=[
            OpenApiParameter("search", str, description="Название или код МКБ-10"),
            OpenApiParameter("status", str, enum=ClinicalGuidelineStatus.values),
        ],
        responses=OpenApiTypes.OBJECT,
        tags=["references"],
    )
    def get(self, request):
        rows = references.search_guidelines(
            request.query_params.get("search", "")[:100], request.query_params.get("status")
        )
        return Response([guideline_brief(g) for g in rows])


class GuidelineDetailView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT, tags=["references"])
    def get(self, request, guideline_id):
        item = references.guideline(guideline_id)
        version = item.current_version
        codes = ICD10Code.objects.filter(code__in=item.icd_codes).order_by("code")
        lessons = selectors.published_lessons(published_revision__in=references.lessons_citing(item))
        return Response(
            {
                **guideline_brief(item),
                "developer": item.developer,
                "summary": version.summary if version else [],
                "source_url": version.source_url if version else "",
                "icd": [icd_brief(c) for c in codes],
                "versions": [
                    {
                        "version": v.version_label,
                        "approved_at": v.approved_at,
                        "current": v.pk == item.current_version_id,
                    }
                    for v in references.versions(item)
                ],
                "lessons": [{"id": lesson.pk, "title": lesson.published_revision.title} for lesson in lessons],
            }
        )
