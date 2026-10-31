from django.urls import path

from . import views

urlpatterns = [
    path("auth/register", views.RegisterView.as_view(), name="auth-register"),
    path("auth/verify-email", views.VerifyEmailView.as_view(), name="auth-verify-email"),
    path("auth/resend-code", views.ResendCodeView.as_view(), name="auth-resend-code"),
    path("auth/login", views.LoginView.as_view(), name="auth-login"),
    path("auth/refresh", views.RefreshView.as_view(), name="auth-refresh"),
    path("auth/logout", views.LogoutView.as_view(), name="auth-logout"),
    path("auth/password/forgot", views.ForgotPasswordView.as_view(), name="auth-password-forgot"),
    path("auth/password/reset", views.ResetPasswordView.as_view(), name="auth-password-reset"),
    path("auth/password/change", views.ChangePasswordView.as_view(), name="auth-password-change"),
    path("auth/sessions", views.SessionListView.as_view(), name="auth-sessions"),
    path("auth/sessions/<uuid:session_id>", views.SessionDetailView.as_view(), name="auth-session-detail"),
    path("me", views.MeView.as_view(), name="me"),
    path("me/deletion-code", views.DeletionCodeView.as_view(), name="me-deletion-code"),
    path("me/delete", views.DeleteAccountView.as_view(), name="me-delete"),
    path("me/export", views.ExportView.as_view(), name="me-export"),
    path("me/consents", views.ConsentListView.as_view(), name="me-consents"),
]
