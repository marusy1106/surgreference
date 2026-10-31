import pytest
from django.db import IntegrityError

from apps.gamification.models import XpEvent, XpReason

pytestmark = pytest.mark.django_db


def test_idempotency_key_prevents_double_award(make_user):
    user = make_user()
    data = {"user": user, "amount": 20, "reason": XpReason.LESSON_COMPLETED, "source_type": "lesson", "source_id": "1"}
    XpEvent.objects.create(idempotency_key="lesson:1:user", **data)
    with pytest.raises(IntegrityError):
        XpEvent.objects.create(idempotency_key="lesson:1:user", **data)
