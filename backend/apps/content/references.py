"""Справочники: МКБ-10 (импорт из НСИ Минздрава) и реестр клинических рекомендаций с версиями.

Когда КР пересматривают или выходит новая версия, опубликованные уроки со ссылкой на неё
(блок guideline_ref) попадают в очередь перепроверки ContentRecheck (docs/05-learning.md, 5.2).
"""

import re

from django.contrib.contenttypes.models import ContentType
from django.db import IntegrityError, transaction
from django.db.models import Q
from django.db.models.functions import Collate
from django.shortcuts import get_object_or_404
from django.utils import timezone

from .models import (
    ClinicalGuideline,
    ClinicalGuidelineStatus,
    ContentRecheck,
    ICD10Code,
    LessonRevision,
    ReviewStatus,
)

SEARCH_LIMIT = 50

# Порядок по кодам символов: кириллица в нём алфавитная, и он не зависит от локали сервера БД
# (en_US.UTF-8 на macOS сортирует кириллицу неверно).
BY_TITLE = Collate("title", "C")

# Пользователи набирают код кириллицей: «К35» выглядит как «K35».
_CYRILLIC_LOOKALIKES = str.maketrans("АВЕКМНОРСТХ", "ABEKMHOPCTX")
_CODE = re.compile(r"^[A-Z]\d")


def normalize(text: str) -> str:
    return text.strip().lower().replace("ё", "е")


def as_code(query: str) -> str | None:
    """«к35,8» → «K35.8»; None — запрос не похож на код."""
    code = query.strip().upper().translate(_CYRILLIC_LOOKALIKES).replace(",", ".")
    return code if _CODE.match(code) else None


def _title_words(queryset, field, query):
    for word in normalize(query).split():
        queryset = queryset.filter(**{f"{field}__icontains": word})
    return queryset


# --- МКБ-10 --------------------------------------------------------------------------------


def search_icd10(query: str):
    """По коду — префикс («K35» найдёт K35 и K35.2), по названию — все слова в любом порядке.
    Без запроса — классы верхнего уровня."""
    codes = ICD10Code.objects.all()
    if not query.strip():
        return codes.filter(parent__isnull=True).order_by("code")
    if code := as_code(query):
        found = codes.filter(code__startswith=code)
        if "-" not in code:
            found = found.exclude(code__contains="-")  # диапазоны блоков («K35-K38») — только по запросу с дефисом
        return found.order_by("code")[:SEARCH_LIMIT]
    return _title_words(codes, "title", query).order_by("code")[:SEARCH_LIMIT]


def icd10_code(code: str):
    return get_object_or_404(ICD10Code.objects.select_related("parent"), code=as_code(code) or code)


def ancestors(code: ICD10Code) -> list[ICD10Code]:
    chain = []
    node = code.parent
    while node is not None and len(chain) < 10:
        chain.append(node)
        node = node.parent
    return chain[::-1]


def _related(guideline_code: str, code: str) -> bool:
    return guideline_code == code or guideline_code.startswith(f"{code}.") or code.startswith(f"{guideline_code}.")


def guidelines_for_code(code: str):
    """КР, где указан этот код, его рубрика (K35 для K35.8) или подрубрика (K35.8 для K35)."""
    candidates = ClinicalGuideline.objects.exclude(status=ClinicalGuidelineStatus.WITHDRAWN).select_related(
        "current_version"
    )
    return [g for g in candidates if any(_related(c, code) for c in g.icd_codes)]


# --- Клинические рекомендации ------------------------------------------------------------


def search_guidelines(query: str = "", status: str | None = None):
    """По коду МКБ — КР с этим кодом или его рубрикой, по названию — все слова в любом порядке."""
    guidelines = ClinicalGuideline.objects.select_related("current_version").order_by(BY_TITLE)
    if status in ClinicalGuidelineStatus.values:
        guidelines = guidelines.filter(status=status)
    if not query.strip():
        return guidelines[:SEARCH_LIMIT]
    if code := as_code(query):
        root = code.split(".")[0]
        return guidelines.filter(Q(icd_codes__contains=[code]) | Q(icd_codes__contains=[root]))[:SEARCH_LIMIT]
    return _title_words(guidelines, "title", query)[:SEARCH_LIMIT]


def guideline(guideline_id):
    return get_object_or_404(ClinicalGuideline.objects.select_related("current_version"), pk=guideline_id)


def versions(guideline_obj):
    return guideline_obj.versions.order_by("-approved_at", "-pk")


def lessons_citing(guideline_obj):
    """Опубликованные ревизии уроков с блоком guideline_ref на эту КР."""
    return LessonRevision.objects.filter(
        status=ReviewStatus.PUBLISHED,
        body__contains=[{"type": "guideline_ref", "guideline_id": guideline_obj.pk}],
    )


def queue_rechecks(guideline_obj, reason: str) -> int:
    """Поставить в очередь все опубликованные уроки со ссылкой на КР. Уже открытая перепроверка не дублируется."""
    content_type = ContentType.objects.get_for_model(LessonRevision)
    queued = 0
    for revision in lessons_citing(guideline_obj):
        try:
            with transaction.atomic():
                ContentRecheck.objects.create(
                    content_type=content_type, object_id=revision.pk, guideline=guideline_obj, reason=reason
                )
            queued += 1
        except IntegrityError:
            continue
    return queued


@transaction.atomic
def set_current_version(guideline_obj, version, user) -> int:
    """Новая версия КР становится текущей: прежняя помечается заменённой, уроки со ссылкой — на перепроверку."""
    if version.guideline_id != guideline_obj.pk:
        raise ValueError("Версия относится к другой КР")
    previous = guideline_obj.current_version
    if previous is not None and previous.pk != version.pk:
        previous.superseded_by = version
        previous.save(update_fields=["superseded_by", "updated_at"])
    version.checked_by = user
    version.checked_at = timezone.now()
    version.save(update_fields=["checked_by", "checked_at", "updated_at"])
    guideline_obj.current_version = version
    guideline_obj.status = ClinicalGuidelineStatus.ACTIVE
    guideline_obj.save(update_fields=["current_version", "status", "updated_at"])
    if previous is None or previous.pk == version.pk:
        return 0
    return queue_rechecks(guideline_obj, f"Новая версия КР: {version.version_label}")


def check_revisions(today=None) -> int:
    """Раз в сутки (Celery beat): КР с наступившим сроком планового пересмотра → «на пересмотре»,
    уроки со ссылкой на неё — на перепроверку."""
    today = today or timezone.localdate()
    due = ClinicalGuideline.objects.filter(
        status=ClinicalGuidelineStatus.ACTIVE, current_version__revision_due__lte=today
    ).select_related("current_version")
    marked = 0
    for item in due:
        item.status = ClinicalGuidelineStatus.UNDER_REVISION
        item.save(update_fields=["status", "updated_at"])
        queue_rechecks(item, f"Наступил срок пересмотра КР ({item.current_version.revision_due:%d.%m.%Y})")
        marked += 1
    return marked


def resolve_rechecks(rechecks, user) -> int:
    return rechecks.filter(resolved_at__isnull=True).update(resolved_at=timezone.now(), resolved_by=user)


# --- Ссылки из уроков ----------------------------------------------------------------------


def resolve_blocks(body, published_at):
    """Блоки icd_ref и guideline_ref дополняются данными справочников на момент запроса: название кода,
    актуальная версия и статус КР; revised — КР пересмотрена или заменена после публикации урока."""
    codes = {b["code"] for b in body if isinstance(b, dict) and b.get("type") == "icd_ref"}
    ids = {b["guideline_id"] for b in body if isinstance(b, dict) and b.get("type") == "guideline_ref"}
    titles = dict(ICD10Code.objects.filter(code__in=codes).values_list("code", "title")) if codes else {}
    guidelines = (
        {g.pk: g for g in ClinicalGuideline.objects.filter(pk__in=ids).select_related("current_version")} if ids else {}
    )
    resolved = []
    for block in body:
        kind = block.get("type") if isinstance(block, dict) else None
        if kind == "icd_ref":
            block = {**block, "title": titles.get(block["code"], "")}
        elif kind == "guideline_ref" and (g := guidelines.get(block["guideline_id"])):
            version = g.current_version
            block = {
                **block,
                "title": g.title,
                "status": g.status,
                "version": version.version_label if version else "",
                "revised": g.status != ClinicalGuidelineStatus.ACTIVE
                or bool(version and published_at and version.approved_at > published_at.date()),
            }
        resolved.append(block)
    return resolved
