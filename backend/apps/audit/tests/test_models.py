import pytest

from apps.audit.models import AppendOnlyError, SecurityEvent

pytestmark = pytest.mark.django_db


def test_security_event_is_append_only(make_user):
    event = SecurityEvent.objects.create(event="login", outcome="success", actor=make_user())
    event.details = {"tampered": True}
    with pytest.raises(AppendOnlyError):
        event.save()
    with pytest.raises(AppendOnlyError):
        event.delete()
