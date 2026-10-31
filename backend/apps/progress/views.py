from drf_spectacular.utils import OpenApiTypes, extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.content import selectors as content

from . import selectors, services


class DisciplineListView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT, operation_id="disciplines_list", tags=["learning"])
    def get(self, request):
        """Каталог дисциплин с освоением текущего пользователя."""
        return Response(selectors.disciplines_overview(request.user))


class DisciplineDetailView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT, tags=["learning"])
    def get(self, request, slug):
        """Темы дисциплины: уроки (с отметкой «пройден»), тест темы, освоение."""
        return Response(selectors.discipline_detail(request.user, slug))


class LessonCompleteView(APIView):
    @extend_schema(request=None, responses=OpenApiTypes.OBJECT, tags=["learning"])
    def post(self, request, lesson_id):
        lesson = content.published_lesson(lesson_id)
        first_time = services.complete_lesson(request.user, lesson)
        return Response({"completed": True, "first_time": first_time})
