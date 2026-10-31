from datetime import timedelta

from django.db.models import Sum
from django.db.models.functions import TruncDate

from apps.assessment import selectors as assessment
from apps.progress import selectors as progress

from . import clock
from .levels import xp_for_level
from .models import Achievement, UserAchievement, UserStats, XpEvent

MONTHS = ["янв", "фев", "мар", "апр", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
WEEKDAYS = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]


def _xp_since(user, start, end=None):
    qs = XpEvent.objects.filter(user=user, created_at__gte=clock.start_of(start))
    if end:
        qs = qs.filter(created_at__lt=clock.start_of(end))
    return qs.aggregate(s=Sum("amount"))["s"] or 0


def overview(user):
    """Сводка для главной и профиля: уровень, серия, XP за неделю, «продолжить», слабая тема."""
    stats = UserStats.objects.filter(user=user).first() or UserStats(user=user)
    week = clock.week_start()
    # Серия, не продлённая вчера или сегодня, уже прервана — показываем 0, не дожидаясь записи.
    streak_alive = stats.last_active_date is not None and stats.last_active_date >= clock.today() - timedelta(days=1)
    lesson = progress.last_unfinished_lesson(user)
    weak = progress.weakest_topic(user)
    attempt = assessment.last_finished_attempt(user)
    return {
        "level": stats.level,
        "total_xp": stats.total_xp,
        "level_xp": xp_for_level(stats.level),
        "next_level_xp": xp_for_level(stats.level + 1),
        "current_streak": stats.current_streak if streak_alive else 0,
        "longest_streak": stats.longest_streak,
        "week_xp": _xp_since(user, week),
        "previous_week_xp": _xp_since(user, week - timedelta(days=7), week),
        "lessons_completed": stats.lessons_completed,
        "quizzes_finished": stats.quizzes_finished,
        "cases_finished": stats.cases_finished,
        "disciplines": progress.disciplines_overview(user),
        "continue_lesson": lesson
        and {
            "id": lesson.pk,
            "title": lesson.published_revision.title,
            "discipline": lesson.topic.discipline.title,
            "palette_token": lesson.topic.discipline.palette_token,
        },
        "weak_topic": weak
        and {
            "id": weak.topic_id,
            "title": weak.topic.title,
            "mastery": float(weak.mastery),
            "discipline_slug": weak.topic.discipline.slug,
        },
        "last_quiz": attempt
        and {
            "quiz_id": attempt.quiz_id,
            "topic": attempt.quiz.topic.title if attempt.quiz.topic_id else attempt.quiz.title,
            "correct": attempt.correct_count,
            "total": attempt.total_count,
            "palette_token": attempt.discipline.palette_token,
        },
    }


def activity(user, period):
    """XP по дням (неделя, месяц) или по месяцам (год) в учебном часовом поясе."""
    today = clock.today()
    if period == "year":
        first = today.replace(day=1)
        months = []
        for _ in range(12):
            months.insert(0, first)
            first = (first - timedelta(days=1)).replace(day=1)
        buckets = [(m, (m + timedelta(days=32)).replace(day=1)) for m in months]
        labels = [MONTHS[m.month - 1] for m in months]
    else:
        days = 7 if period == "week" else 30
        starts = [today - timedelta(days=days - 1 - i) for i in range(days)]
        buckets = [(d, d + timedelta(days=1)) for d in starts]
        labels = [WEEKDAYS[d.weekday()] if period == "week" else f"{d.day}.{d.month:02d}" for d in starts]

    rows = (
        XpEvent.objects.filter(user=user, created_at__gte=clock.start_of(buckets[0][0]))
        .annotate(day=TruncDate("created_at", tzinfo=clock.tz()))
        .values("day")
        .annotate(xp=Sum("amount"))
    )
    by_day = {r["day"]: r["xp"] for r in rows}
    values = [sum(xp for day, xp in by_day.items() if start <= day < end) for start, end in buckets]
    return {"period": period, "points": [{"label": lbl, "xp": v} for lbl, v in zip(labels, values, strict=True)]}


def achievements(user):
    earned = dict(UserAchievement.objects.filter(user=user).values_list("achievement_id", "earned_at"))
    return [
        {
            "code": a.code,
            "title": a.title,
            "description": a.description,
            "icon": a.icon,
            "earned_at": earned.get(a.pk),
        }
        for a in Achievement.objects.filter(is_active=True).order_by("pk")
        if not a.is_hidden or a.pk in earned
    ]
