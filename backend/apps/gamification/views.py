from drf_spectacular.utils import OpenApiParameter, OpenApiTypes, extend_schema
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from . import selectors


class ProgressView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT, tags=["progress"])
    def get(self, request):
        return Response(selectors.overview(request.user))


class ActivityView(APIView):
    @extend_schema(
        parameters=[OpenApiParameter("period", enum=["week", "month", "year"], default="week")],
        responses=OpenApiTypes.OBJECT,
        tags=["progress"],
    )
    def get(self, request):
        period = request.query_params.get("period", "week")
        if period not in {"week", "month", "year"}:
            raise ValidationError({"period": ["Допустимо: week, month, year"]})
        return Response(selectors.activity(request.user, period))


class AchievementsView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT, tags=["progress"])
    def get(self, request):
        return Response(selectors.achievements(request.user))
