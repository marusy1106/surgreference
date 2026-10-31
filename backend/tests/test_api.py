import pytest
from django.core.management import call_command

pytestmark = pytest.mark.django_db


def test_health(api_client):
    response = api_client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "db": True}


def test_app_config_exposes_flags(api_client):
    body = api_client.get("/api/v1/app/config").json()
    assert body["monetization_enabled"] is False
    assert body["flags"]["cases_enabled"] is True
    assert set(body["legal_documents"]) == {"pd_processing", "terms", "privacy_policy"}


def test_openapi_schema(api_client):
    response = api_client.get("/api/v1/schema/", HTTP_ACCEPT="application/json")
    assert response.status_code == 200
    assert response.json()["info"]["title"] == "SurgReference API"


def test_errors_use_unified_format(api_client):
    response = api_client.post("/api/v1/health")
    assert response.status_code == 405
    assert set(response.json()["error"]) == {"code", "message"}


def test_no_missing_migrations():
    call_command("makemigrations", "--check", "--dry-run", verbosity=0)
