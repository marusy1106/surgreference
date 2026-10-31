"""Учебные сутки и периоды считаются в LEARNING_TIME_ZONE, а не в UTC."""

from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from django.conf import settings
from django.utils import timezone


def tz():
    return ZoneInfo(settings.LEARNING_TIME_ZONE)


def today() -> date:
    return timezone.now().astimezone(tz()).date()


def start_of(day: date) -> datetime:
    return datetime.combine(day, time.min, tzinfo=tz())


def week_start(day: date | None = None) -> date:
    day = day or today()
    return day - timedelta(days=day.weekday())


def month_start(day: date | None = None) -> date:
    return (day or today()).replace(day=1)
