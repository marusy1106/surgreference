from apps.core.ratelimit import client_ip

from .models import SecurityEvent


def record_security_event(
    event, *, outcome=SecurityEvent.Outcome.SUCCESS, request=None, actor=None, subject=None, ip=None, **details
):
    """Пишет событие в журнал безопасности. Пароли, коды и токены в details не передаются."""
    user_agent = ""
    if request is not None:
        ip = ip or client_ip(request)
        user_agent = request.META.get("HTTP_USER_AGENT", "")[:256]
    return SecurityEvent.objects.create(
        event=event,
        outcome=outcome,
        actor=actor,
        subject=subject or actor,
        ip=ip,
        user_agent=user_agent,
        details=details,
    )
