from drf_spectacular.utils import OpenApiTypes, extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.assessment import selectors as assessment
from apps.assessment.serializers import attempt_payload
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


class PracticeView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT, tags=["learning"])
    def get(self, request):
        """Дисциплины для тренировки: число вопросов и ошибок, доступна ли работа над ошибками."""
        return Response(selectors.practice_overview(request.user))


class TrainingView(APIView):
    @extend_schema(request=None, responses={201: OpenApiTypes.OBJECT}, tags=["learning"])
    def post(self, request, slug):
        """Тренировка: 10 случайных вопросов дисциплины, чаще — из тем с низким освоением."""
        attempt = services.start_training(request.user, content.published_discipline(slug))
        return Response(attempt_payload(attempt, assessment.attempt_answers(attempt)), status=status.HTTP_201_CREATED)


class MistakesView(APIView):
    @extend_schema(request=None, responses={201: OpenApiTypes.OBJECT}, tags=["learning"])
    def post(self, request, slug):
        """Работа над ошибками: до 10 вопросов, на которые последний ответ был неверным."""
        attempt = services.start_mistakes(request.user, content.published_discipline(slug))
        return Response(attempt_payload(attempt, assessment.attempt_answers(attempt)), status=status.HTTP_201_CREATED)
