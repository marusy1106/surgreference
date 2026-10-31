from drf_spectacular.utils import OpenApiTypes, extend_schema
from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from . import selectors, services
from .models import CaseAttemptStatus
from .serializers import case_header, outcome_payload, review_payload, step_payload


class ChoiceInputSerializer(serializers.Serializer):
    choice_id = serializers.IntegerField()


class CaseListView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT, tags=["cases"])
    def get(self, request):
        return Response([case_header(case) for case in selectors.published_cases()])


class CaseAttemptsView(APIView):
    @extend_schema(request=None, responses={201: OpenApiTypes.OBJECT}, tags=["cases"])
    def post(self, request, case_id):
        case = selectors.published_case(case_id)
        attempt = services.start_attempt(request.user, case)
        steps = selectors.decision_steps(case)
        return Response(
            {
                "attempt_id": str(attempt.pk),
                "case": case_header(case),
                "step_titles": [(s.content or {}).get("title", "") for s in steps],
                "step": step_payload(steps[0], 1, len(steps)),
            },
            status=status.HTTP_201_CREATED,
        )


class CaseChoiceView(APIView):
    @extend_schema(request=ChoiceInputSerializer, responses=OpenApiTypes.OBJECT, tags=["cases"])
    def post(self, request, attempt_id):
        """Выбор на текущем шаге → качество, обратная связь, оптимальный вариант, следующий шаг."""
        attempt = selectors.user_attempt(request.user, attempt_id)
        serializer = ChoiceInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        choice, next_step, attempt = services.choose(attempt, serializer.validated_data["choice_id"])
        return Response(outcome_payload(choice, next_step, attempt, selectors.decision_steps(attempt.case)))


class CaseReviewView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT, tags=["cases"])
    def get(self, request, attempt_id):
        attempt = selectors.user_attempt(request.user, attempt_id, status=CaseAttemptStatus.FINISHED)
        return Response(review_payload(attempt, selectors.chosen_path(attempt)))
