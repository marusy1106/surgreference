from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.db import IntegrityError, transaction
from django.db.models import F, Sum

from apps.assessment import selectors as assessment
from apps.assessment import services as assessment_services
from apps.cases import selectors as cases
from apps.cases import services as cases_services
from apps.universities.models import EducationProfile

from . import clock
from .levels import level_for_xp
from .models import Achievement, UserAchievement, UserStats, XpEvent, XpReason

# Правила начисления — docs/05-learning.md, 5.6.
LESSON_XP = 20
QUIZ_CORRECT_XP = 2
QUIZ_BONUS_XP = 10
QUIZ_BONUS_AT = Decimal("0.8")
CASE_MAX_XP = 30
STREAK_XP = 5


def stats_for(user):
    stats, _ = UserStats.objects.get_or_create(user=user)
    return stats


def _university_id(user):
    return EducationProfile.objects.filter(user=user).values_list("university_id", flat=True).first()


def award_xp(user, amount, reason, *, source_type, source_id, key) -> int:
    """Начислить XP с учётом суточного лимита. Повтор с тем же ключом ничего не начисляет.
    Возвращает фактически начисленное."""
    if amount <= 0:
        return 0
    stats = UserStats.objects.select_for_update().get_or_create(user=user)[0]
    earned_today = (
        XpEvent.objects.filter(user=user, created_at__gte=clock.start_of(clock.today()), amount__gt=0).aggregate(
            s=Sum("amount")
        )["s"]
        or 0
    )
    amount = min(amount, settings.XP_DAILY_CAP - earned_today)
    if amount <= 0:
        return 0
    try:
        with transaction.atomic():
            XpEvent.objects.create(
                user=user,
                amount=amount,
                reason=reason,
                source_type=source_type,
                source_id=str(source_id),
                university_id=_university_id(user),
                idempotency_key=key,
            )
    except IntegrityError:
        return 0
    stats.total_xp += amount
    stats.level = level_for_xp(stats.total_xp)
    stats.save(update_fields=["total_xp", "level", "updated_at"])
    return amount


def record_activity(user):
    """Учебный день засчитан: продлить серию; со 2-го дня серии — +5 XP за день."""
    stats = UserStats.objects.select_for_update().get_or_create(user=user)[0]
    day = clock.today()
    if stats.last_active_date == day:
        return
    stats.current_streak = stats.current_streak + 1 if stats.last_active_date == day - timedelta(days=1) else 1
    stats.longest_streak = max(stats.longest_streak, stats.current_streak)
    stats.last_active_date = day
    stats.save(update_fields=["current_streak", "longest_streak", "last_active_date", "updated_at"])
    if stats.current_streak >= 2:
        award_xp(user, STREAK_XP, XpReason.STREAK, source_type="streak", source_id=day, key=f"streak:{user.pk}:{day}")


def _increment(user, field):
    UserStats.objects.filter(user=user).update(**{field: F(field) + 1})


def check_achievements(user, *, perfect_quiz=False):
    """Критерии: {"type": "count", "metric": <поле UserStats>, "gte": N} и {"type": "perfect_quiz"}."""
    stats = UserStats.objects.get(user=user)
    owned = set(UserAchievement.objects.filter(user=user).values_list("achievement_id", flat=True))
    for achievement in Achievement.objects.filter(is_active=True).exclude(pk__in=owned):
        criteria = achievement.criteria or {}
        kind = criteria.get("type")
        if kind == "count":
            reached = getattr(stats, criteria.get("metric", ""), 0) >= criteria.get("gte", 0)
        elif kind == "perfect_quiz":
            reached = perfect_quiz
        else:
            continue
        if not reached:
            continue
        UserAchievement.objects.get_or_create(user=user, achievement=achievement)
        award_xp(
            user,
            achievement.xp_reward,
            XpReason.ACHIEVEMENT,
            source_type="achievement",
            source_id=achievement.code,
            key=f"achievement:{user.pk}:{achievement.code}",
        )


# --- Получатели доменных событий ---------------------------------------------------


@transaction.atomic
def on_lesson_completed(sender, user, lesson, **kwargs):
    stats_for(user)
    _increment(user, "lessons_completed")
    award_xp(
        user,
        LESSON_XP,
        XpReason.LESSON_COMPLETED,
        source_type="lesson",
        source_id=lesson.pk,
        key=f"lesson:{user.pk}:{lesson.pk}",
    )
    record_activity(user)
    check_achievements(user)


@transaction.atomic
def on_quiz_attempt_finished(sender, attempt, **kwargs):
    user = attempt.user
    stats_for(user)
    _increment(user, "quizzes_finished")
    awarded = 0
    if not attempt.flagged:
        best = assessment.best_previous_correct(attempt)
        # Первая попытка — за каждый верный; повтор — только за верные сверх лучшего прошлого результата.
        new_correct = attempt.correct_count if best is None else max(0, attempt.correct_count - best)
        awarded += award_xp(
            user,
            QUIZ_CORRECT_XP * new_correct,
            XpReason.QUIZ_CORRECT,
            source_type="quiz_attempt",
            source_id=attempt.pk,
            key=f"quiz:{attempt.pk}",
        )
        if attempt.score is not None and attempt.score >= QUIZ_BONUS_AT:
            awarded += award_xp(
                user,
                QUIZ_BONUS_XP,
                XpReason.QUIZ_BONUS,
                source_type="quiz",
                source_id=attempt.quiz_id,
                key=f"quiz_bonus:{user.pk}:{attempt.quiz_id}",
            )
    assessment_services.set_xp_awarded(attempt, awarded)
    record_activity(user)
    check_achievements(user, perfect_quiz=attempt.total_count > 0 and attempt.correct_count == attempt.total_count)


@transaction.atomic
def on_case_attempt_finished(sender, attempt, **kwargs):
    user = attempt.user
    stats_for(user)
    _increment(user, "cases_finished")
    # XP = 30 × доля баллов; повтор кейса добавляет только прирост к лучшему прошлому результату.
    best = cases.best_previous_score(attempt) or Decimal(0)
    target = round(CASE_MAX_XP * float(attempt.score or 0))
    already = round(CASE_MAX_XP * float(best))
    awarded = award_xp(
        user,
        target - already,
        XpReason.CASE_COMPLETED,
        source_type="case_attempt",
        source_id=attempt.pk,
        key=f"case:{attempt.pk}",
    )
    cases_services.set_xp_awarded(attempt, awarded)
    record_activity(user)
    check_achievements(user)
