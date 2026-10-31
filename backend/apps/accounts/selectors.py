from django.utils import timezone

from .models import UserSession


def active_sessions(user):
    return UserSession.objects.filter(user=user, revoked_at__isnull=True, expires_at__gt=timezone.now()).order_by(
        "-last_used_at"
    )
