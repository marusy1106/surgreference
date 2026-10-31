from django.conf import settings
from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from config import views as system_views

admin.site.site_header = "SurgReference — администрирование"
admin.site.site_title = "SurgReference"

api_v1 = [
    path("health", system_views.health, name="health"),
    path("app/config", system_views.app_config, name="app-config"),
]

if settings.API_DOCS_ENABLED:
    api_v1 += [
        path("schema/", SpectacularAPIView.as_view(permission_classes=[]), name="schema"),
        path(
            "docs/",
            SpectacularSwaggerView.as_view(url_name="api-v1:schema", permission_classes=[]),
            name="docs",
        ),
    ]

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/", include((api_v1, "api-v1"))),
]
