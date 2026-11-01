import secrets

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.contrib.contenttypes.models import ContentType
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django_otp.plugins.otp_totp.models import TOTPDevice

from apps.content.models import (
    ContentSource,
    Discipline,
    Lesson,
    LessonRevision,
    Source,
    SourceKind,
    SourceLicense,
    Topic,
)

# Вымышленные сотрудники на зарезервированном домене (RFC 2606): автор, рецензент хирургии, главный редактор.
STAFF = [
    ("demo-author@example.org", "Автор (демо)", "content_author"),
    ("demo-reviewer@example.org", "Рецензент (демо)", "medical_reviewer"),
    ("demo-editor@example.org", "Главный редактор (демо)", "chief_editor"),
]

DRAFT_BODY = [
    {"type": "paragraph", "text": "Острый холецистит — воспаление жёлчного пузыря, чаще всего на фоне камней."},
    {"type": "heading", "text": "Клиническая картина"},
    {"type": "list", "items": ["Боль в правом подреберье", "Лихорадка", "Симптом Мерфи"]},
    {"type": "callout", "text": "Учебный текст для показа редакционного процесса, не для обучения."},
]


class Command(BaseCommand):
    help = "Демо-сотрудники редакции и черновик урока для показа редакционного процесса (только для разработки)"

    def handle(self, *args, **options):
        if not settings.DEBUG:
            raise CommandError("Только для разработки (DEBUG=True)")
        password = secrets.token_urlsafe(12)
        with transaction.atomic():
            users = {role: self._staff(email, name, role, password) for email, name, role in STAFF}
            surgery = Discipline.objects.get(slug="surgery")
            surgery.reviewers.add(users["medical_reviewer"])
            self._draft(surgery, users["content_author"])
        self.stdout.write("Сотрудники (пароль общий; второй фактор нужен, только если ADMIN_REQUIRE_OTP включён):")
        for email, _, role in STAFF:
            self.stdout.write(f"  {role:18} {email}")
        self.stdout.write(f"Пароль: {password}")

    def _staff(self, email, name, role, password):
        user, _ = get_user_model().objects.get_or_create(
            email=email, defaults={"display_name": email.split("@")[0][:32], "first_name": name}
        )
        user.is_staff = True
        user.is_active = True
        user.set_password(password)
        user.save()
        user.groups.set([Group.objects.get(name=role)])
        TOTPDevice.objects.get_or_create(user=user, defaults={"name": "демо", "confirmed": True})
        return user

    def _draft(self, surgery, author):
        topic = Topic.objects.get(discipline=surgery, slug="cholecystitis")
        lesson, _ = Lesson.objects.get_or_create(topic=topic, slug="clinic")
        if lesson.revisions.exists():
            return
        revision = LessonRevision.objects.create(
            lesson=lesson, version=1, title="Острый холецистит: клиника", body=DRAFT_BODY, author=author
        )
        source, _ = Source.objects.get_or_create(
            title="Клинические рекомендации Минздрава России «Острый холецистит»",
            defaults={"kind": SourceKind.CLINICAL_GUIDELINE, "license": SourceLicense.CITATION},
        )
        ContentSource.objects.create(
            content_type=ContentType.objects.get_for_model(revision), object_id=revision.pk, source=source
        )
