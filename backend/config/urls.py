from django.conf import settings
from django.contrib import admin
from django.urls import include, path
from django_otp.admin import OTPAdminSite
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from apps.accounts.admin_forms import AuditedOTPAdminAuthenticationForm
from config import views as system_views

# Админка открывается только после второго фактора (TOTP или резервный код), docs/04, 4.5.
admin.site.__class__ = OTPAdminSite
admin.site.login_form = AuditedOTPAdminAuthenticationForm
admin.site.site_header = "SurgReference — администрирование"
admin.site.site_title = "SurgReference"

api_v1 = [
    path("health", system_views.health, name="health"),
    path("app/config", system_views.app_config, name="app-config"),
    path("", include("apps.accounts.urls")),
    path("", include("apps.universities.urls")),
    path("", include("apps.content.urls")),
    path("", include("apps.progress.urls")),
    path("", include("apps.assessment.urls")),
    path("", include("apps.cases.urls")),
    path("", include("apps.gamification.urls")),
    path("", include("apps.leaderboards.urls")),
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
