from django.contrib.auth import get_user_model
from django.db.models import Sum

from apps.accounts.models import UserTrustStatus
from apps.gamification import clock
from apps.gamification.models import UserStats, XpEvent
from apps.universities.models import EducationProfile, University

TOP = 50

# Вуз попадает в рейтинг при ≥ 5 активных участниках (docs/05-learning.md, 5.7).
UNIVERSITY_MIN_PARTICIPANTS = 5


def period_start(period):
    return {"week": clock.week_start(), "month": clock.month_start(), "all_time": None}[period]


def participants():
    """Кто виден в рейтингах: согласились участвовать, подтвердили email, активны, без подозрений."""
    return get_user_model().objects.filter(
        leaderboard_opt_in=True,
        is_active=True,
        deleted_at__isnull=True,
        email_verified_at__isnull=False,
        trust_status=UserTrustStatus.OK,
    )


def _events(period):
    start = period_start(period)
    events = XpEvent.objects.filter(user__in=participants())
    return events.filter(created_at__gte=clock.start_of(start)) if start else events


def user_board(user, *, period, scope):
    """Топ участников по XP за период и своё место, даже вне топа."""
    university_id = None
    events = _events(period)
    if scope == "university":
        university_id = EducationProfile.objects.filter(user=user).values_list("university_id", flat=True).first()
        if university_id is None:
            return {"rows": [], "me": None, "participants": 0, "needs_university": True}
        events = events.filter(user__education__university_id=university_id)

    totals = list(events.values("user_id").annotate(xp=Sum("amount")).filter(xp__gt=0).order_by("-xp", "user_id"))
    ranked = [(i + 1, row["user_id"], row["xp"]) for i, row in enumerate(totals)]
    shown = {uid for _, uid, _ in ranked[:TOP]} | {user.pk}
    people = {u.pk: u for u in get_user_model().objects.filter(pk__in=shown).select_related("education__university")}
    levels = dict(UserStats.objects.filter(user__in=shown).values_list("user_id", "level"))

    def row(rank, uid, xp):
        person = people[uid]
        education = getattr(person, "education", None)
        return {
            "rank": rank,
            "display_name": person.display_name,
            "level": levels.get(uid, 1),
            "university": education.university.name if education and education.university else None,
            "xp": xp,
            "is_me": uid == user.pk,
        }

    mine = next((r for r in ranked if r[1] == user.pk), None)
    return {
        "rows": [row(*r) for r in ranked[:TOP]],
        "me": row(*mine) if mine and user.leaderboard_opt_in else None,
        "participants": len(ranked),
        "needs_university": False,
    }


def university_board(*, period):
    """Балл вуза — среднее XP на активного участника за период (XP — по вузу на момент начисления)."""
    per_user = (
        _events(period)
        .filter(university__isnull=False)
        .values("university_id", "user_id")
        .annotate(xp=Sum("amount"))
        .filter(xp__gt=0)
    )
    totals = {}
    for r in per_user:
        xp, n = totals.get(r["university_id"], (0, 0))
        totals[r["university_id"]] = (xp + r["xp"], n + 1)
    eligible = {uid: (xp / n, n) for uid, (xp, n) in totals.items() if n >= UNIVERSITY_MIN_PARTICIPANTS}
    names = dict(University.objects.filter(pk__in=eligible).values_list("pk", "name"))
    ordered = sorted(eligible.items(), key=lambda item: (-item[1][0], names.get(item[0], "")))
    return {
        "rows": [
            {"rank": i + 1, "name": names[uid], "score": round(score, 1), "participants": n}
            for i, (uid, (score, n)) in enumerate(ordered[:TOP])
        ],
        "min_participants": UNIVERSITY_MIN_PARTICIPANTS,
    }
