from drf_spectacular.utils import extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from . import selectors
from .serializers import LessonSerializer


class LessonView(APIView):
    @extend_schema(responses=LessonSerializer, tags=["learning"])
    def get(self, request, lesson_id):
        lesson = selectors.published_lesson(lesson_id)
        sources = selectors.sources_for(lesson.published_revision)
        return Response(LessonSerializer(lesson, context={"sources": sources}).data)
