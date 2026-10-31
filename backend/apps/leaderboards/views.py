from drf_spectacular.utils import OpenApiParameter, OpenApiTypes, extend_schema
from rest_framework import serializers
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts import services as accounts

from . import selectors

PERIODS = ["week", "month", "all_time"]


class BoardQuerySerializer(serializers.Serializer):
    period = serializers.ChoiceField(choices=PERIODS, default="week")
    scope = serializers.ChoiceField(choices=["global", "university"], default="global")


class ParticipationSerializer(serializers.Serializer):
    opt_in = serializers.BooleanField()


class UserBoardView(APIView):
    @extend_schema(
        parameters=[
            OpenApiParameter("period", enum=PERIODS, default="week"),
            OpenApiParameter("scope", enum=["global", "university"], default="global"),
        ],
        responses=OpenApiTypes.OBJECT,
        tags=["leaderboards"],
    )
    def get(self, request):
        query = BoardQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        board = selectors.user_board(request.user, **query.validated_data)
        return Response({**board, "opted_in": request.user.leaderboard_opt_in})


class UniversityBoardView(APIView):
    @extend_schema(
        parameters=[OpenApiParameter("period", enum=PERIODS, default="week")],
        responses=OpenApiTypes.OBJECT,
        tags=["leaderboards"],
    )
    def get(self, request):
        query = BoardQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        return Response(selectors.university_board(period=query.validated_data["period"]))


class ParticipationView(APIView):
    @extend_schema(request=ParticipationSerializer, responses=ParticipationSerializer, tags=["leaderboards"])
    def put(self, request):
        serializer = ParticipationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = accounts.set_leaderboard_opt_in(request.user, serializer.validated_data["opt_in"], request=request)
        return Response({"opt_in": user.leaderboard_opt_in})
