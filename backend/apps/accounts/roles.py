"""Роли сотрудников (docs/04, 4.5) — Django Groups, синхронизируются после каждой миграции.

Права перечисляются явно: что не указано, роли недоступно (принцип наименьших привилегий).
superadmin — это флаг is_superuser, отдельной группы нет: только он выдаёт роли и видит журналы.
Бизнес-правила редакционного процесса (рецензент ≠ автор, публикует только chief_editor) проверяются
в коде и ограничениях БД, права здесь лишь открывают разделы админки.
"""

VIEW = ("view",)
EDIT = ("view", "add", "change")
FULL = ("view", "add", "change", "delete")

CONTENT_MODELS = (
    "content.source",
    "content.discipline",
    "content.topic",
    "content.lesson",
    "content.lessonrevision",
    "content.contentsource",
    "content.icd10code",
    "content.clinicalguideline",
    "content.guidelineversion",
    "content.mediaasset",
    "assessment.question",
    "assessment.answeroption",
    "assessment.quiz",
    "assessment.quizquestion",
    "cases.clinicalcase",
    "cases.casestep",
    "cases.casechoice",
    "gamification.achievement",
)

ROLES = {
    "content_author": {
        **dict.fromkeys(CONTENT_MODELS, EDIT),
        "content.contentreview": VIEW,
    },
    "medical_reviewer": {
        **dict.fromkeys(CONTENT_MODELS, VIEW),
        "content.lessonrevision": ("view", "change"),
        "assessment.question": ("view", "change"),
        "cases.clinicalcase": ("view", "change"),
        "content.contentreview": EDIT,
    },
    "chief_editor": {
        **dict.fromkeys(CONTENT_MODELS, FULL),
        "content.contentreview": EDIT,
    },
    "support": {
        "accounts.user": ("view", "change"),
        "accounts.usersession": VIEW,
        "accounts.consent": VIEW,
        "accounts.datasubjectrequest": EDIT,
        "universities.university": EDIT,
        "universities.faculty": EDIT,
        "universities.universityrequest": ("view", "change"),
        "feedback.feedback": ("view", "change"),
    },
    # Аналитик видит только агрегаты: без доступа к пользователям и их email.
    "analyst": {
        "analytics.dailymetrics": VIEW,
        "leaderboards.leaderboardsnapshot": VIEW,
        "universities.university": VIEW,
        "feedback.feedback": VIEW,
    },
}


def sync_roles(using="default", **kwargs):
    from django.apps import apps
    from django.contrib.auth.management import create_permissions
    from django.contrib.auth.models import Group, Permission

    # post_migrate приходит по приложениям по очереди: права моделей, стоящих после accounts,
    # к этому моменту ещё не созданы — создаём их заранее (операция идемпотентна).
    for app_config in apps.get_app_configs():
        create_permissions(app_config, verbosity=0, using=using)

    for name, grants in ROLES.items():
        group, _ = Group.objects.get_or_create(name=name)
        wanted = []
        for model_label, actions in grants.items():
            app_label, model = model_label.split(".")
            codenames = [f"{action}_{model}" for action in actions]
            found = Permission.objects.filter(content_type__app_label=app_label, codename__in=codenames)
            if found.count() != len(codenames):
                raise LookupError(f"Нет прав {codenames} для {model_label}: проверьте ROLES")
            wanted.extend(found)
        group.permissions.set(wanted)
