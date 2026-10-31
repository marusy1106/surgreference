from django import forms
from django_otp.admin import OTPAdminAuthenticationForm

from apps.audit.models import SecurityEvent
from apps.audit.services import record_security_event


class AuditedOTPAdminAuthenticationForm(OTPAdminAuthenticationForm):
    """Неверный второй фактор пишется в журнал: пароль при этом верный, и user_login_failed не срабатывает."""

    def clean_otp(self, user):
        try:
            super().clean_otp(user)
        except forms.ValidationError:
            if self.data.get("otp_token"):
                record_security_event(
                    "admin.mfa", outcome=SecurityEvent.Outcome.FAILURE, request=self.request, subject=user
                )
            raise
