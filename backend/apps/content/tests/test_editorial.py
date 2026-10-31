import io
import json
from datetime import date

import pytest
from django.contrib.auth.models import Group
from django.contrib.contenttypes.models import ContentType
from django.core.management import call_command
from django.urls import reverse
from django_otp.oath import totp
from django_otp.plugins.otp_totp.models import TOTPDevice

from apps.content import editorial
from apps.content.editorial import EditorialError
from apps.content.models import (
    CatalogStatus,
    ContentReview,
    ContentSource,
    Discipline,
    Lesson,
    LessonRevision,
    ReviewStatus,
    Source,
    SourceKind,
    SourceLicense,
    Topic,
)

pytestmark = pytest.mark.django_db

BODY = [
    {"type": "heading", "text": "Диагностика"},
    {"type": "paragraph", "text": "Диагноз ставится клинически."},
    {"type": "table", "header": ["Признак", "Баллы"], "rows": [["Лейкоцитоз", "2"]]},
]


@pytest.fixture
def discipline():
    return Discipline.objects.create(slug="surgery", title="Хирургия", status=CatalogStatus.PUBLISHED)


@pytest.fixture
def lesson(discipline):
    topic = Topic.objects.create(discipline=discipline, slug="appendicitis", title="Аппендицит", status="published")
    return Lesson.objects.create(topic=topic, slug="diagnosis")


@pytest.fixture
def author(staff):
    return staff("content_author")


@pytest.fixture
def reviewer(staff, discipline):
    user = staff("medical_reviewer")
    discipline.reviewers.add(user)
    return user


@pytest.fixture
def editor(staff):
    return staff("chief_editor")


@pytest.fixture
def source():
    return Source.objects.create(
        title="КР «Острый аппендицит у взрослых»", kind=SourceKind.CLINICAL_GUIDELINE, license=SourceLicense.CITATION
    )


def cite(obj, source):
    ContentSource.objects.create(content_type=ContentType.objects.get_for_model(obj), object_id=obj.pk, source=source)


@pytest.fixture
def draft(lesson, author, source):
    revision = LessonRevision.objects.create(lesson=lesson, version=1, title="Аппендицит", body=BODY, author=author)
    cite(revision, source)
    return revision


def publish_flow(revision, author, reviewer, editor):
    editorial.submit(revision, author)
    editorial.review(revision, reviewer, "approve")
    return editorial.publish(revision, editor)


def test_full_flow_publishes_lesson(draft, author, reviewer, editor, as_user, make_user):
    published = publish_flow(draft, author, reviewer, editor)

    assert published.status == ReviewStatus.PUBLISHED
    assert published.reviewer == reviewer
    assert published.publisher == editor
    assert Lesson.objects.get(pk=draft.lesson_id).published_revision_id == draft.pk
    decisions = list(editorial.history(draft).values_list("decision", flat=True))
    assert decisions == ["publish", "approve", "submit"]
    body = as_user(make_user()).get(f"/api/v1/lessons/{draft.lesson_id}").json()
    assert body["title"] == "Аппендицит"


def test_submit_requires_source(lesson, author):
    revision = LessonRevision.objects.create(lesson=lesson, version=1, title="Без источников", body=BODY, author=author)

    with pytest.raises(EditorialError, match="источник"):
        editorial.submit(revision, author)


def test_submit_checks_blocks(draft, author):
    draft.body = [{"type": "video", "url": "x"}, {"type": "table", "header": ["a", "b"], "rows": [["1"]]}]
    draft.save()

    with pytest.raises(EditorialError) as error:
        editorial.submit(draft, author)

    assert "Блок 1: неизвестный тип «video»" in str(error.value)
    assert "Блок 2: table" in str(error.value)


def test_licensed_source_needs_rights_document(draft, author, source):
    source.license = SourceLicense.LICENSED
    source.save()

    with pytest.raises(EditorialError, match="нет документа о правах"):
        editorial.submit(draft, author)


def test_expired_rights_block_publication(draft, author, reviewer, editor, source):
    editorial.submit(draft, author)
    editorial.review(draft, reviewer, "approve")
    source.rights_expires_at = date(2020, 1, 1)
    source.save()

    with pytest.raises(EditorialError, match="права истекли"):
        editorial.publish(draft, editor)


def test_only_author_or_chief_editor_submits(draft, reviewer, editor):
    with pytest.raises(EditorialError, match="автор"):
        editorial.submit(draft, reviewer)

    assert editorial.submit(draft, editor).status == ReviewStatus.IN_REVIEW


def test_author_cannot_review_own_work_even_as_reviewer(draft, author, discipline):
    author.groups.add(Group.objects.get(name="medical_reviewer"))
    discipline.reviewers.add(author)
    editorial.submit(draft, author)

    with pytest.raises(EditorialError, match="рецензент"):
        editorial.review(draft, author, "approve")


def test_reviewer_must_be_assigned_to_discipline(draft, author, staff):
    stranger = staff("medical_reviewer")
    editorial.submit(draft, author)

    with pytest.raises(EditorialError, match="рецензент дисциплины"):
        editorial.review(draft, stranger, "approve")


def test_request_changes_needs_comment_then_author_resubmits(draft, author, reviewer):
    editorial.submit(draft, author)
    with pytest.raises(EditorialError, match="что исправить"):
        editorial.review(draft, reviewer, "request_changes", "  ")

    editorial.review(draft, reviewer, "request_changes", "Добавьте шкалу Альварадо целиком")
    draft.refresh_from_db()
    assert draft.status == ReviewStatus.CHANGES_REQUESTED
    assert editorial.can_edit(author, draft)

    assert editorial.submit(draft, author).status == ReviewStatus.IN_REVIEW
    assert ContentReview.objects.filter(comment="Добавьте шкалу Альварадо целиком").exists()


def test_reject_archives(draft, author, reviewer):
    editorial.submit(draft, author)

    assert editorial.review(draft, reviewer, "reject", "Тема уже есть").status == ReviewStatus.ARCHIVED


def test_only_chief_editor_publishes(draft, author, reviewer):
    editorial.submit(draft, author)
    editorial.review(draft, reviewer, "approve")

    with pytest.raises(EditorialError, match="главный редактор"):
        editorial.publish(draft, reviewer)


def test_wrong_status_is_rejected(draft, editor):
    with pytest.raises(EditorialError, match="черновик"):
        editorial.publish(draft, editor)


def test_new_version_replaces_published_atomically(draft, author, reviewer, editor, source):
    publish_flow(draft, author, reviewer, editor)

    second = editorial.new_version(draft, author)
    assert second.version == 2
    assert second.status == ReviewStatus.DRAFT
    assert [s.source_id for s in ContentSource.objects.filter(object_id=second.pk)] == [source.pk]
    with pytest.raises(EditorialError, match="уже начата"):
        editorial.new_version(draft, author)
    assert Lesson.objects.get(pk=draft.lesson_id).published_revision_id == draft.pk, "users still see v1"

    second.title = "Аппендицит (2026)"
    second.save()
    publish_flow(second, author, reviewer, editor)

    draft.refresh_from_db()
    assert draft.status == ReviewStatus.ARCHIVED
    assert Lesson.objects.get(pk=draft.lesson_id).published_revision_id == second.pk


def test_withdraw_needs_reason_and_hides_lesson(draft, author, reviewer, editor):
    publish_flow(draft, author, reviewer, editor)
    with pytest.raises(EditorialError, match="причину"):
        editorial.withdraw(draft, editor)

    editorial.withdraw(draft, editor, "Устаревшая дозировка")

    assert Lesson.objects.get(pk=draft.lesson_id).published_revision is None


def test_allowed_actions_by_role(draft, author, reviewer, editor):
    assert editorial.allowed_actions(author, draft) == ["submit"]
    assert editorial.allowed_actions(reviewer, draft) == []
    draft = editorial.submit(draft, author)
    assert editorial.allowed_actions(reviewer, draft) == ["approve", "request_changes", "reject"]
    assert editorial.allowed_actions(author, draft) == []
    draft = editorial.review(draft, reviewer, "approve")
    assert editorial.allowed_actions(editor, draft) == ["publish"]
    draft = editorial.publish(draft, editor)
    assert editorial.allowed_actions(editor, draft) == ["withdraw", "new_version"]
    assert editorial.allowed_actions(author, draft) == ["new_version"]


# --- Админка (вход со вторым фактором, как в проде) -------------------------------------------


def login(client, user):
    call_command("enroll_totp", user.email, stdout=io.StringIO())
    device = TOTPDevice.objects.get(user=user)
    data = {
        "username": user.email,
        "password": "correct-horse-battery",
        "otp_token": totp(device.bin_key),
        "otp_device": device.persistent_id,
    }
    assert client.post("/admin/login/?next=/admin/", data).status_code == 302


def editorial_url(revision):
    return reverse("admin:content_lessonrevision_editorial", args=[revision.pk])


def test_admin_editorial_page_and_actions(client, draft, author, reviewer):
    login(client, author)
    page = client.get(editorial_url(draft))
    assert page.status_code == 200
    assert "Отправить на проверку" in page.content.decode()

    response = client.post(editorial_url(draft), {"action": "submit"})
    assert response.status_code == 302
    draft.refresh_from_db()
    assert draft.status == ReviewStatus.IN_REVIEW

    login(client, reviewer)
    client.post(editorial_url(draft), {"action": "request_changes", "comment": ""})
    draft.refresh_from_db()
    assert draft.status == ReviewStatus.IN_REVIEW, "empty comment is refused"
    client.post(editorial_url(draft), {"action": "request_changes", "comment": "Уточните источник"})
    draft.refresh_from_db()
    assert draft.status == ReviewStatus.CHANGES_REQUESTED


def test_admin_locks_fields_after_submit(client, draft, author):
    login(client, author)
    change = reverse("admin:content_lessonrevision_change", args=[draft.pk])
    assert 'name="title"' in client.get(change).content.decode()

    editorial.submit(draft, author)

    assert 'name="title"' not in client.get(change).content.decode()


def test_admin_new_revision_gets_next_version_and_author(client, lesson, author):
    LessonRevision.objects.create(lesson=lesson, version=1, title="v1", body=BODY, author=author)
    login(client, author)

    response = client.post(
        reverse("admin:content_lessonrevision_add"),
        {
            "lesson": lesson.pk,
            "title": "Новая",
            "body": json.dumps(BODY),
            "estimated_minutes": 5,
            "change_summary": "",
            "content-contentsource-content_type-object_id-TOTAL_FORMS": 0,
            "content-contentsource-content_type-object_id-INITIAL_FORMS": 0,
        },
    )

    assert response.status_code == 302
    created = LessonRevision.objects.get(title="Новая")
    assert (created.version, created.author) == (2, author)


def test_review_queue_filter(client, draft, author, reviewer):
    editorial.submit(draft, author)
    login(client, reviewer)

    page = client.get(reverse("admin:content_lessonrevision_changelist"), {"queue": "review"})

    assert page.status_code == 200
    assert "Аппендицит" in page.content.decode()
