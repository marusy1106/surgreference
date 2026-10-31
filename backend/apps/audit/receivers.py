from django.contrib.admin.models import ADDITION, CHANGE, DELETION, LogEntry
from django.contrib.auth.signals import user_logged_in, user_login_failed
from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.core.ratelimit import client_ip

from .models import AdminAuditLog, SecurityEvent
from .services import record_security_event

ACTIONS = {ADDITION: "add", CHANGE: "change", DELETION: "delete"}


def _is_admin_request(request):
    return request is not None and request.path.startswith("/admin/")


@receiver(post_save, sender=LogEntry, dispatch_uid="audit.admin_log_entry")
def copy_admin_log_entry(sender, instance, created, **kwargs):
    """Каждое действие в админке дублируется в append-only журнал (LogEntry Django можно удалить)."""
    if not created:
        return
    AdminAuditLog.objects.create(
        staff_user_id=instance.user_id,
        action=ACTIONS.get(instance.action_flag, str(instance.action_flag)),
        model=instance.content_type.model_class()._meta.label if instance.content_type_id else "",
        object_id=str(instance.object_id or "")[:64],
        diff={"change": instance.get_change_message(), "object": instance.object_repr},
    )


@receiver(user_logged_in, dispatch_uid="audit.admin_login")
def admin_login(sender, request, user, **kwargs):
    if _is_admin_request(request):
        record_security_event("admin.login", request=request, actor=user, ip=client_ip(request))


@receiver(user_login_failed, dispatch_uid="audit.admin_login_failed")
def admin_login_failed(sender, credentials, request=None, **kwargs):
    if _is_admin_request(request):
        record_security_event("admin.login", outcome=SecurityEvent.Outcome.FAILURE, request=request)
