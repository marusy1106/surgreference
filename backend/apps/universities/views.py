from drf_spectacular.utils import OpenApiParameter, OpenApiTypes, extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from . import selectors, services
from .models import SpecialtyLevel
from .serializers import (
    EducationInputSerializer,
    UniversityRequestSerializer,
    profile_payload,
    specialty_payload,
    university_payload,
)


class UniversityListView(APIView):
    @extend_schema(
        parameters=[OpenApiParameter("search", str, description="Название, сокращение, «Первый мед», город")],
        responses=OpenApiTypes.OBJECT,
        tags=["education"],
    )
    def get(self, request):
        """Поиск по справочнику вузов, не больше 20 результатов."""
        rows = selectors.search_universities(request.query_params.get("search", "")[:100])
        return Response([university_payload(u) for u in rows])


class FacultyListView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT, tags=["education"])
    def get(self, request, university_id):
        university = selectors.active_university(university_id)
        return Response([{"id": f.pk, "name": f.name} for f in selectors.faculties(university)])


class SpecialtyListView(APIView):
    @extend_schema(
        parameters=[OpenApiParameter("level", str, enum=SpecialtyLevel.values)],
        responses=OpenApiTypes.OBJECT,
        tags=["education"],
    )
    def get(self, request):
        level = request.query_params.get("level")
        return Response(
            [specialty_payload(s) for s in selectors.specialties(level if level in SpecialtyLevel.values else None)]
        )


class UniversityRequestView(APIView):
    @extend_schema(request=UniversityRequestSerializer, responses={201: OpenApiTypes.OBJECT}, tags=["education"])
    def post(self, request):
        """«Моего вуза нет»: заявка на модерацию. После одобрения вуз появится в профиле сам."""
        serializer = UniversityRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        created = services.request_university(request.user, **serializer.validated_data)
        return Response({"name": created.name, "city": created.city}, status=status.HTTP_201_CREATED)


class EducationView(APIView):
    def _payload(self, user):
        return profile_payload(selectors.education_profile(user), selectors.open_request(user))

    @extend_schema(responses=OpenApiTypes.OBJECT, tags=["education"])
    def get(self, request):
        """Учебный профиль: статус, вуз, специальность, курс. Отдельно от уровня знаний."""
        return Response(self._payload(request.user))

    @extend_schema(request=EducationInputSerializer, responses=OpenApiTypes.OBJECT, tags=["education"])
    def put(self, request):
        serializer = EducationInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.save_profile(request.user, **serializer.validated_data)
        return Response(self._payload(request.user))

    @extend_schema(request=None, responses={204: None}, tags=["education"])
    def delete(self, request):
        services.delete_profile(request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class EducationHistoryView(APIView):
    @extend_schema(responses=OpenApiTypes.OBJECT, tags=["education"])
    def get(self, request):
        return Response([{"snapshot": h.snapshot, "changed_at": h.changed_at} for h in selectors.history(request.user)])
