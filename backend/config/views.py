from django.conf import settings
from django.db import connection
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.billing import flags


@extend_schema(
    responses=inline_serializer("Health", {"status": serializers.CharField(), "db": serializers.BooleanField()}),
    tags=["system"],
)
@api_view(["GET"])
@permission_classes([AllowAny])
@throttle_classes([])
def health(request):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        db_ok = True
    except Exception:  # noqa: BLE001 — health-check не должен падать
        db_ok = False
    return Response({"status": "ok" if db_ok else "degraded", "db": db_ok}, status=200 if db_ok else 503)


@extend_schema(
    responses=inline_serializer(
        "AppConfig",
        {
            "min_app_version": serializers.CharField(),
            "monetization_enabled": serializers.BooleanField(),
            "flags": serializers.DictField(child=serializers.BooleanField()),
            "legal_documents": serializers.DictField(child=serializers.CharField()),
        },
    ),
    tags=["system"],
)
@api_view(["GET"])
@permission_classes([AllowAny])
def app_config(request):
    """Конфигурация клиента: флаги, минимальная версия, версии юридических документов."""
    public_flags = flags.public_flags(user=request.user)
    return Response(
        {
            "min_app_version": settings.MIN_APP_VERSION,
            "monetization_enabled": public_flags.get(flags.MONETIZATION_ENABLED, False),
            "flags": public_flags,
            "legal_documents": settings.LEGAL_DOCUMENT_VERSIONS,
        }
    )
