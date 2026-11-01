import io
from datetime import date, timedelta

import pytest
from django.contrib.contenttypes.models import ContentType
from django.core.management import call_command
from django.urls import reverse
from django.utils import timezone

from apps.content import references
from apps.content.models import (
    ClinicalGuideline,
    ClinicalGuidelineStatus,
    ContentRecheck,
    GuidelineVersion,
    ICD10Code,
    Lesson,
    LessonRevision,
    lesson_block_problems,
)

pytestmark = [pytest.mark.django_db, pytest.mark.usefixtures("demo_content")]


@pytest.fixture
def client_api(as_user, make_user):
    return as_user(make_user())


@pytest.fixture
def appendicitis():
    return ClinicalGuideline.objects.get(title="Острый аппендицит у взрослых")


@pytest.fixture
def lesson():
    return Lesson.objects.select_related("published_revision").get(topic__slug="appendicitis", slug="diagnosis")


def new_version(guideline, label="демо-3", approved=None):
    return GuidelineVersion.objects.create(
        guideline=guideline,
        version_label=label,
        approved_at=approved or timezone.localdate(),
        source_url="https://cr.minzdrav.gov.ru/",
    )


@pytest.mark.parametrize(("query", "code"), [("к35,8", "K35.8"), (" K35 ", "K35"), ("аппендицит", None)])
def test_as_code_accepts_cyrillic_lookalikes(query, code):
    assert references.as_code(query) == code


def test_icd10_search(client_api):
    roots = client_api.get("/api/v1/icd10").json()
    assert [r["code"] for r in roots] == ["I00-I99", "J00-J99", "K00-K93"]

    by_code = client_api.get("/api/v1/icd10", {"search": "к35"}).json()
    assert [r["code"] for r in by_code] == ["K35", "K35.2", "K35.3", "K35.8"]

    by_words = client_api.get("/api/v1/icd10", {"search": "перитонитом острый"}).json()
    assert {r["code"] for r in by_words} == {"K35.2", "K35.3"}


def test_icd10_code_page(client_api, appendicitis):
    body = client_api.get("/api/v1/icd10/K35.8").json()

    assert body["title"] == "Острый аппендицит, другой и неуточненный"
    assert [a["code"] for a in body["ancestors"]] == ["K00-K93", "K35-K38", "K35"]
    assert body["children"] == []
    assert [g["id"] for g in body["guidelines"]] == [appendicitis.pk], "КР на рубрику K35 относится и к K35.8"

    parent = client_api.get("/api/v1/icd10/K35").json()
    assert [c["code"] for c in parent["children"]] == ["K35.2", "K35.3", "K35.8"]
    assert client_api.get("/api/v1/icd10/Z99").status_code == 404


def test_guideline_search_and_status(client_api):
    titles = [g["title"] for g in client_api.get("/api/v1/guidelines").json()]
    assert titles == ["Острый аппендицит у взрослых", "Острый панкреатит", "Острый холецистит"]

    by_code = client_api.get("/api/v1/guidelines", {"search": "K81.0"}).json()
    assert [g["title"] for g in by_code] == ["Острый холецистит"]

    revising = client_api.get("/api/v1/guidelines", {"status": "under_revision"}).json()
    assert [g["title"] for g in revising] == ["Острый холецистит"]


def test_guideline_page(client_api, appendicitis, lesson):
    body = client_api.get(f"/api/v1/guidelines/{appendicitis.pk}").json()

    assert body["version"] == "демо-2"
    assert [(v["version"], v["current"]) for v in body["versions"]] == [("демо-2", True), ("демо-1", False)]
    assert [c["code"] for c in body["icd"]] == ["K35", "K36", "K37"]
    assert body["lessons"] == [{"id": lesson.pk, "title": lesson.published_revision.title}]
    assert body["summary"][0].startswith("Демо-данные")


def test_requires_authentication(api_client):
    assert api_client.get("/api/v1/icd10").status_code == 401
    assert api_client.get("/api/v1/guidelines").status_code == 401


def test_lesson_resolves_reference_blocks(client_api, appendicitis, lesson, staff):
    blocks = client_api.get(f"/api/v1/lessons/{lesson.pk}").json()["body"]
    icd = next(b for b in blocks if b["type"] == "icd_ref")
    ref = next(b for b in blocks if b["type"] == "guideline_ref")
    assert icd["title"] == "Острый аппендицит"
    assert (ref["title"], ref["version"], ref["status"], ref["revised"]) == (
        "Острый аппендицит у взрослых",
        "демо-2",
        "active",
        False,
    )

    # Вышла новая версия КР после публикации урока — читатель видит пометку.
    references.set_current_version(
        appendicitis, new_version(appendicitis, approved=date.today() + timedelta(1)), staff()
    )
    ref = next(b for b in client_api.get(f"/api/v1/lessons/{lesson.pk}").json()["body"] if b["type"] == "guideline_ref")
    assert (ref["version"], ref["revised"]) == ("демо-3", True)


def test_new_version_queues_recheck_once(appendicitis, lesson, staff):
    editor = staff("chief_editor")
    queued = references.set_current_version(appendicitis, new_version(appendicitis), editor)

    assert queued == 1
    recheck = ContentRecheck.objects.get()
    assert recheck.object_id == lesson.published_revision_id
    assert "демо-3" in recheck.reason
    assert (
        GuidelineVersion.objects.get(guideline=appendicitis, version_label="демо-2").superseded_by.version_label
        == "демо-3"
    )

    references.queue_rechecks(appendicitis, "ещё раз")
    assert ContentRecheck.objects.count() == 1, "открытая перепроверка не дублируется"

    references.resolve_rechecks(ContentRecheck.objects.all(), editor)
    assert references.queue_rechecks(appendicitis, "после проверки") == 1


def test_check_revisions_marks_due_guidelines(appendicitis):
    marked = references.check_revisions(today=date(2027, 1, 1))

    appendicitis.refresh_from_db()
    assert marked == 1
    assert appendicitis.status == ClinicalGuidelineStatus.UNDER_REVISION
    assert ContentRecheck.objects.filter(guideline=appendicitis).count() == 1
    assert references.check_revisions(today=date(2027, 1, 1)) == 0


def test_reference_blocks_are_validated():
    assert lesson_block_problems({"type": "icd_ref", "code": "K35"}) == []
    assert "нет в справочнике" in lesson_block_problems({"type": "icd_ref", "code": "Z99"})[0]
    assert "нет в реестре" in lesson_block_problems({"type": "guideline_ref", "guideline_id": 999999})[0]


def test_import_icd10(tmp_path):
    path = tmp_path / "mkb.csv"
    path.write_text(
        "ID;ID_PARENT;MKB_CODE;MKB_NAME;ACTUAL\n"
        "1;;A00-B99;Класс I. Некоторые инфекционные и паразитарные болезни;1\n"
        "2;1;A00-A09;Кишечные инфекции;1\n"
        "3;2;A00;Холера;1\n"
        "4;3;A00.0;Холера, вызванная холерным вибрионом 01, биовар cholerae;1\n"
        "5;3;A00.9;Холера неуточненная;0\n"
        "6;K35-K38;K35;Острый аппендицит (новое название);1\n",
        encoding="utf-8",
    )

    call_command("import_icd10", str(path), nsi_version="5.12", stdout=io.StringIO())

    cholera = ICD10Code.objects.get(code="A00")
    assert (cholera.parent_id, cholera.chapter, cholera.block, cholera.is_leaf) == (
        "A00-A09",
        "A00-B99",
        "A00-A09",
        False,
    )
    assert ICD10Code.objects.get(code="A00.0").is_leaf
    assert not ICD10Code.objects.filter(code="A00.9").exists(), "неактуальные записи не импортируются"
    assert ICD10Code.objects.get(code="K35").title == "Острый аппендицит (новое название)"


# --- Админка -----------------------------------------------------------------------------


@pytest.fixture
def admin_client_for(client):
    """Вход в админку со вторым фактором без ввода кода (сам вход проверяет test_editorial)."""
    from django_otp.plugins.otp_totp.models import TOTPDevice

    def _as(user):
        device = TOTPDevice.objects.create(user=user, name="test", confirmed=True)
        client.force_login(user)
        session = client.session
        session["otp_device_id"] = device.persistent_id
        session.save()
        return client

    return _as


def test_admin_make_current_only_by_chief_editor(admin_client_for, appendicitis, staff):
    version = new_version(appendicitis)
    url = reverse("admin:content_guidelineversion_changelist")
    data = {"action": "make_current", "_selected_action": [version.pk]}

    admin_client_for(staff("content_author")).post(url, data)
    appendicitis.refresh_from_db()
    assert appendicitis.current_version.version_label == "демо-2"

    admin_client_for(staff("chief_editor")).post(url, data)
    appendicitis.refresh_from_db()
    assert appendicitis.current_version_id == version.pk
    assert ContentRecheck.objects.filter(guideline=appendicitis).count() == 1


def test_admin_resolves_rechecks(admin_client_for, appendicitis, staff):
    references.queue_rechecks(appendicitis, "пересмотр")
    recheck = ContentRecheck.objects.get()
    client = admin_client_for(staff("chief_editor"))

    page = client.get(reverse("admin:content_contentrecheck_changelist"))
    assert page.status_code == 200
    assert "пересмотр" in page.content.decode()

    client.post(
        reverse("admin:content_contentrecheck_changelist"), {"action": "resolve", "_selected_action": [recheck.pk]}
    )
    recheck.refresh_from_db()
    assert recheck.resolved_at is not None
    assert ContentType.objects.get_for_model(LessonRevision) == recheck.content_type
