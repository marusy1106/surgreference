from drf_spectacular.utils import OpenApiTypes, extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.content import selectors as content

from . import selectors, services
from .models import QuizAttemptStatus
from .serializers import AnswerInputSerializer, attempt_payload, result_payload, review_payload


class QuizAttemptsView(APIView):
    @extend_schema(request=None, responses={201: OpenApiTypes.OBJECT}, tags=["quizzes"])
    def post(self, request, quiz_id):
        """Начать попытку: вопросы приходят без правильных ответов."""
        attempt = services.start_attempt(request.user, selectors.published_quiz(quiz_id))
        rows = selectors.attempt_answers(attempt)
        return Response(attempt_payload(attempt, rows), status=status.HTTP_201_CREATED)


class AttemptAnswerView(APIView):
    @extend_schema(request=AnswerInputSerializer, responses={204: None}, tags=["quizzes"])
    def post(self, request, attempt_id):
        attempt = selectors.user_attempt(request.user, attempt_id)
        serializer = AnswerInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.answer(attempt, **serializer.validated_data)
        return Response(status=status.HTTP_204_NO_CONTENT)


class AttemptFinishView(APIView):
    @extend_schema(request=None, responses=OpenApiTypes.OBJECT, tags=["quizzes"])
    def post(self, request, attempt_id):
        """Подсчёт результата и начисление XP. Повторный вызов вернёт тот же результат."""
        attempt = services.finish(selectors.user_attempt(request.user, attempt_id))
        return Response(result_payload(attempt))


class AttemptReviewView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT, tags=["quizzes"])
    def get(self, request, attempt_id):
        """Разбор: выбранные и правильные варианты с объяснением каждого. Только после завершения."""
        attempt = selectors.user_attempt(request.user, attempt_id, status=QuizAttemptStatus.FINISHED)
        lesson = content.published_lessons(topic_id=attempt.quiz.topic_id).first() if attempt.quiz.topic_id else None
        return Response(review_payload(attempt, selectors.attempt_answers(attempt), lesson.pk if lesson else None))
