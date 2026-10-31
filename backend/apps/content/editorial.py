"""Редакционный процесс (docs/05-learning.md, 5.2) для любой единицы контента с медицинской проверкой:
ревизии урока, вопроса, клинического кейса.

    черновик → на проверке → одобрено → опубликовано → в архиве
                   ↓   ↑
              нужны правки

Правила проверяются здесь, а не в админке: рецензент ≠ автор и закреплён за дисциплиной, публикует
только главный редактор, без источников с подтверждёнными правами на проверку не отправить.
Каждый переход пишется в журнал ContentReview.
"""

from django.contrib.contenttypes.models import ContentType
from django.db import transaction
from django.utils import timezone

from .models import ContentReview, ContentReviewDecision, ContentSource, Discipline, ReviewStatus, SourceLicense
from .selectors import sources_for

EDITABLE = (ReviewStatus.DRAFT, ReviewStatus.CHANGES_REQUESTED)

# Лицензии, для которых нужен документ о правах (договор, письменное разрешение).
NEEDS_RIGHTS_DOCUMENT = (SourceLicense.LICENSED, SourceLicense.PERMISSION)


class EditorialError(Exception):
    """Переход запрещён правилами; текст показывается редактору как есть."""


def _in_group(user, name):
    return user.is_active and user.groups.filter(name=name).exists()


def is_chief_editor(user) -> bool:
    return user.is_active and (user.is_superuser or _in_group(user, "chief_editor"))


def is_reviewer_for(user, obj) -> bool:
    """Роль medical_reviewer и закрепление за дисциплиной контента. Автор своё не проверяет."""
    return (
        user.pk != obj.author_id
        and _in_group(user, "medical_reviewer")
        and Discipline.objects.filter(pk=obj.editorial_discipline_id(), reviewers=user).exists()
    )


def can_edit(user, obj) -> bool:
    """Содержимое правят только в черновике и после возврата — автор или главный редактор.
    Опубликованное неизменяемо: правка = новая версия."""
    return obj.pk is None or (obj.status in EDITABLE and (obj.author_id == user.pk or is_chief_editor(user)))


def can_create(user, model) -> bool:
    meta = model._meta
    return user.has_perm(f"{meta.app_label}.add_{meta.model_name}")


def source_problems(obj) -> list[str]:
    rows = list(sources_for(obj))
    if not rows:
        return ["Не указан ни один источник"]
    problems = []
    today = timezone.localdate()
    for row in rows:
        source = row.source
        if source.license in NEEDS_RIGHTS_DOCUMENT and not source.rights_document_key:
            problems.append(f"«{source}»: нет документа о правах ({source.get_license_display()})")
        if source.rights_expires_at and source.rights_expires_at < today:
            problems.append(f"«{source}»: права истекли {source.rights_expires_at:%d.%m.%Y}")
    return problems


def problems(obj) -> list[str]:
    return [*obj.editorial_problems(), *source_problems(obj)]


def history(obj):
    return (
        ContentReview.objects.filter(content_type=ContentType.objects.get_for_model(obj), object_id=obj.pk)
        .select_related("reviewer")
        .order_by("-created_at", "-pk")
    )


def allowed_actions(user, obj) -> list[str]:
    """Что этот пользователь может сделать сейчас — для кнопок в админке."""
    actions = []
    if obj.status in EDITABLE and can_edit(user, obj):
        actions.append("submit")
    if obj.status == ReviewStatus.IN_REVIEW and is_reviewer_for(user, obj):
        actions += ["approve", "request_changes", "reject"]
    if obj.status == ReviewStatus.APPROVED and is_chief_editor(user):
        actions.append("publish")
    if obj.status == ReviewStatus.PUBLISHED:
        if is_chief_editor(user):
            actions.append("withdraw")
        if can_create(user, type(obj)) and obj.editorial_open_successor() is None:
            actions.append("new_version")
    return actions


def _locked(obj):
    return type(obj).objects.select_for_update().get(pk=obj.pk)


def _log(obj, user, decision, comment=""):
    ContentReview.objects.create(
        content_type=ContentType.objects.get_for_model(obj),
        object_id=obj.pk,
        reviewer=user,
        decision=decision,
        comment=comment,
    )


def _expect(obj, *statuses):
    if obj.status not in statuses:
        raise EditorialError(f"Сейчас статус «{obj.get_status_display()}» — это действие недоступно")


@transaction.atomic
def submit(obj, user):
    obj = _locked(obj)
    _expect(obj, *EDITABLE)
    if not can_edit(user, obj):
        raise EditorialError("Отправить на проверку может автор или главный редактор")
    if found := problems(obj):
        raise EditorialError("Не готово к проверке: " + "; ".join(found))
    obj.status = ReviewStatus.IN_REVIEW
    obj.reviewer = None
    obj.reviewed_at = None
    obj.save(update_fields=["status", "reviewer", "reviewed_at", "updated_at"])
    _log(obj, user, ContentReviewDecision.SUBMIT)
    return obj


@transaction.atomic
def review(obj, user, decision, comment="", *, attest_synthetic=False):
    """Решение рецензента. Вернуть или отклонить можно только с комментарием — автору нужно знать почему."""
    obj = _locked(obj)
    _expect(obj, ReviewStatus.IN_REVIEW)
    if not is_reviewer_for(user, obj):
        raise EditorialError("Решение принимает медицинский рецензент дисциплины, не автор")
    comment = comment.strip()
    if decision in (ContentReviewDecision.REQUEST_CHANGES, ContentReviewDecision.REJECT) and not comment:
        raise EditorialError("Напишите автору, что исправить или почему отклонено")
    if decision == ContentReviewDecision.APPROVE:
        if found := problems(obj):
            raise EditorialError("Нельзя одобрить: " + "; ".join(found))
        if obj.editorial_requires_attestation:
            if not attest_synthetic:
                raise EditorialError("Подтвердите, что пациент в кейсе вымышлен")
            obj.synthetic_attested_by = user
        obj.status = ReviewStatus.APPROVED
        obj.reviewer = user
        obj.reviewed_at = timezone.now()
    elif decision == ContentReviewDecision.REQUEST_CHANGES:
        obj.status = ReviewStatus.CHANGES_REQUESTED
    elif decision == ContentReviewDecision.REJECT:
        obj.status = ReviewStatus.ARCHIVED
    else:
        raise EditorialError(f"Неизвестное решение «{decision}»")
    obj.save()
    _log(obj, user, decision, comment)
    return obj


@transaction.atomic
def publish(obj, user):
    """Атомарно: прежняя опубликованная версия уходит в архив, ссылки переключаются на новую.
    Прогресс пользователей (пройденные уроки, попытки) ссылается на свои версии и не теряется."""
    obj = _locked(obj)
    _expect(obj, ReviewStatus.APPROVED)
    if not is_chief_editor(user):
        raise EditorialError("Публикует только главный редактор")
    if found := source_problems(obj):
        raise EditorialError("Нельзя опубликовать: " + "; ".join(found))
    previous = obj.editorial_previous()
    if previous is not None:
        previous.status = ReviewStatus.ARCHIVED
        previous.save(update_fields=["status", "updated_at"])
    obj.status = ReviewStatus.PUBLISHED
    obj.published_at = timezone.now()
    if hasattr(obj, "publisher"):
        obj.publisher = user
    obj.save()
    obj.editorial_on_published(previous)
    _log(obj, user, ContentReviewDecision.PUBLISH)
    return obj


@transaction.atomic
def withdraw(obj, user, comment=""):
    """Снять с публикации без замены (например, нашли ошибку, а исправление ещё не готово)."""
    obj = _locked(obj)
    _expect(obj, ReviewStatus.PUBLISHED)
    if not is_chief_editor(user):
        raise EditorialError("Снимает с публикации только главный редактор")
    if not comment.strip():
        raise EditorialError("Укажите причину снятия с публикации")
    obj.status = ReviewStatus.ARCHIVED
    obj.save(update_fields=["status", "updated_at"])
    obj.editorial_on_withdrawn()
    _log(obj, user, ContentReviewDecision.WITHDRAW, comment.strip())
    return obj


@transaction.atomic
def new_version(obj, user):
    """Черновик следующей версии с тем же содержимым и источниками. Пока он не опубликован,
    пользователи видят текущую версию."""
    obj = _locked(obj)
    _expect(obj, ReviewStatus.PUBLISHED)
    if not can_create(user, type(obj)):
        raise EditorialError("Нет прав создавать контент")
    if (open_draft := obj.editorial_open_successor()) is not None:
        raise EditorialError(f"Новая версия уже начата: «{open_draft}»")
    copy = obj.editorial_copy(user)
    content_type = ContentType.objects.get_for_model(obj)
    ContentSource.objects.bulk_create(
        ContentSource(content_type=content_type, object_id=copy.pk, source_id=row.source_id, locator=row.locator)
        for row in sources_for(obj)
    )
    return copy
