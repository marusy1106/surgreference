import uuid

from django.db import models
from django.db.models import Q


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField("создано", auto_now_add=True)
    updated_at = models.DateTimeField("изменено", auto_now=True)

    class Meta:
        abstract = True


class UUIDModel(TimeStampedModel):
    """Пользовательские сущности: UUID не раскрывает количество записей."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    class Meta:
        abstract = True


def choices_check(field: str, choices: type[models.Choices], *, nullable: bool = False):
    """CHECK-ограничение уровня БД для поля с перечислением (varchar + CHECK вместо enum)."""
    condition = Q(**{f"{field}__in": choices.values})
    if nullable:
        condition |= Q(**{f"{field}__isnull": True})
    return models.CheckConstraint(condition=condition, name=f"%(app_label)s_%(class)s_{field}_valid")


def range_check(field: str, low: int, high: int, *, nullable: bool = False):
    condition = Q(**{f"{field}__gte": low, f"{field}__lte": high})
    if nullable:
        condition |= Q(**{f"{field}__isnull": True})
    return models.CheckConstraint(condition=condition, name=f"%(app_label)s_%(class)s_{field}_range")


class Platform(models.TextChoices):
    IOS = "ios", "iOS"
    ANDROID = "android", "Android"
