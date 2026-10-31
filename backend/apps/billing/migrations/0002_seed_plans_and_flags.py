from django.db import migrations

FEATURES = {
    "catalog.full": "Полный каталог уроков",
    "quiz.advanced": "Расширенные режимы тестов и работа над ошибками",
    "quiz.training": "Тренировочные вопросы (у Free — лимит в день)",
    "cases.access": "Клинические кейсы (у Free — лимит в месяц)",
    "analytics.advanced": "Расширенная аналитика знаний",
}

# Предварительное распределение (docs/07-monetization.md); окончательное — после 100 пользователей.
PLAN_FEATURES = {
    "free": {"quiz.training": 20, "cases.access": 3},
    "premium": {key: None for key in FEATURES},
}

FLAGS = [
    ("monetization_enabled", False, "Платный доступ. Этап 1: выключен — всё бесплатно", True),
    ("leaderboards_enabled", False, "Рейтинги (включить при ≥ 20 участниках)", True),
    ("cases_enabled", True, "Клинические кейсы", True),
    ("registration_captcha", False, "Капча при регистрации (включается при атаке)", True),
    ("certificate_pinning", True, "Certificate pinning в приложении (аварийное отключение)", True),
    ("university_verification", False, "Подтверждение принадлежности к вузу", True),
]


def seed(apps, schema_editor):
    Plan = apps.get_model("billing", "Plan")
    Feature = apps.get_model("billing", "Feature")
    PlanFeature = apps.get_model("billing", "PlanFeature")
    FeatureFlag = apps.get_model("billing", "FeatureFlag")

    features = {
        key: Feature.objects.get_or_create(key=key, defaults={"description": desc})[0]
        for key, desc in FEATURES.items()
    }
    titles = {"free": "Free", "premium": "Premium"}
    for code, limits in PLAN_FEATURES.items():
        plan, _ = Plan.objects.get_or_create(code=code, defaults={"title": titles[code]})
        for key, limit in limits.items():
            PlanFeature.objects.get_or_create(plan=plan, feature=features[key], defaults={"limit_value": limit})
    for key, enabled, description, is_public in FLAGS:
        FeatureFlag.objects.get_or_create(
            key=key, defaults={"enabled": enabled, "description": description, "is_public": is_public}
        )


class Migration(migrations.Migration):
    dependencies = [("billing", "0001_initial")]

    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
