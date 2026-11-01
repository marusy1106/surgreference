"""Демо-справочники для разработки: фрагмент МКБ-10 и три КР с версиями. Настоящие данные — import_icd10
и реестр КР в админке. Даты и номера версий условные (помечены «демо»), рубрикатор не указан."""

from datetime import date

from django.db import transaction

from .models import ClinicalGuideline, ClinicalGuidelineStatus, GuidelineVersion, ICD10Code, Lesson

NSI_VERSION = "демо"

# (код, родитель, название)
ICD10 = [
    ("K00-K93", None, "Класс XI. Болезни органов пищеварения"),
    ("K35-K38", "K00-K93", "Болезни аппендикса [червеобразного отростка]"),
    ("K35", "K35-K38", "Острый аппендицит"),
    ("K35.2", "K35", "Острый аппендицит с генерализованным перитонитом"),
    ("K35.3", "K35", "Острый аппендицит с локализованным перитонитом"),
    ("K35.8", "K35", "Острый аппендицит, другой и неуточненный"),
    ("K36", "K35-K38", "Другие формы аппендицита"),
    ("K37", "K35-K38", "Аппендицит неуточненный"),
    ("K40-K46", "K00-K93", "Грыжи"),
    ("K40", "K40-K46", "Паховая грыжа"),
    ("K80-K87", "K00-K93", "Болезни желчного пузыря, желчевыводящих путей и поджелудочной железы"),
    ("K80", "K80-K87", "Желчнокаменная болезнь [холелитиаз]"),
    ("K81", "K80-K87", "Холецистит"),
    ("K81.0", "K81", "Острый холецистит"),
    ("K81.1", "K81", "Хронический холецистит"),
    ("K85", "K80-K87", "Острый панкреатит"),
    ("I00-I99", None, "Класс IX. Болезни системы кровообращения"),
    ("I20-I25", "I00-I99", "Ишемическая болезнь сердца"),
    ("I21", "I20-I25", "Острый инфаркт миокарда"),
    ("I60-I69", "I00-I99", "Цереброваскулярные болезни"),
    ("I63", "I60-I69", "Инфаркт мозга"),
    ("J00-J99", None, "Класс X. Болезни органов дыхания"),
    ("J09-J18", "J00-J99", "Грипп и пневмония"),
    ("J18", "J09-J18", "Пневмония без уточнения возбудителя"),
]

DEMO_NOTE = "Демо-данные для разработки: номер версии и даты условные."
CR_URL = "https://cr.minzdrav.gov.ru/"

# (название, коды, статус, разработчик, [(версия, утверждена, пересмотр)], тезисы текущей версии)
GUIDELINES = [
    (
        "Острый аппендицит у взрослых",
        ["K35", "K36", "K37"],
        ClinicalGuidelineStatus.ACTIVE,
        "Российское общество хирургов",
        [("демо-1", date(2021, 1, 1), date(2024, 1, 1)), ("демо-2", date(2024, 1, 1), date(2027, 1, 1))],
        [
            "Диагноз устанавливается по клинической картине, лабораторным данным и результатам визуализации "
            "(УЗИ, КТ по показаниям).",
            "Для оценки вероятности аппендицита используются шкалы (Альварадо, AIR).",
            "Основной метод лечения — аппендэктомия, предпочтительно лапароскопическая.",
        ],
    ),
    (
        "Острый холецистит",
        ["K80", "K81.0"],
        ClinicalGuidelineStatus.UNDER_REVISION,
        "Российское общество хирургов",
        [("демо-1", date(2021, 6, 1), date(2024, 6, 1))],
        [
            "Диагностика и оценка тяжести — по Токийским критериям.",
            "Метод первой линии визуализации — УЗИ.",
            "При отсутствии противопоказаний — ранняя лапароскопическая холецистэктомия.",
        ],
    ),
    (
        "Острый панкреатит",
        ["K85"],
        ClinicalGuidelineStatus.ACTIVE,
        "Российское общество хирургов",
        [("демо-1", date(2024, 3, 1), date(2027, 3, 1))],
        [
            "Тяжесть оценивается по пересмотренной классификации Атланта.",
            "Основа начальной терапии — инфузионная терапия и обезболивание.",
            "КТ с контрастированием — при сомнении в диагнозе и для оценки осложнений.",
        ],
    ),
]


@transaction.atomic
def seed_references() -> dict[str, ClinicalGuideline]:
    """Повторный запуск ничего не дублирует. Возвращает КР по названию."""
    has_children = {parent for _, parent, _ in ICD10 if parent}
    for code, parent, title in ICD10:
        ICD10Code.objects.update_or_create(
            code=code,
            defaults={
                "parent_id": parent,
                "title": title,
                "is_leaf": code not in has_children,
                "nsi_version": NSI_VERSION,
            },
        )

    guidelines = {}
    for title, codes, status, developer, versions, summary in GUIDELINES:
        guideline, created = ClinicalGuideline.objects.get_or_create(
            title=title,
            defaults={"icd_codes": codes, "age_group": ClinicalGuideline.AgeGroup.ADULTS, "developer": developer},
        )
        guidelines[title] = guideline
        if not created:
            continue
        previous = None
        for label, approved, revision_due in versions:
            version = GuidelineVersion.objects.create(
                guideline=guideline,
                version_label=label,
                approved_at=approved,
                revision_due=revision_due,
                summary=[DEMO_NOTE, *summary],
                source_url=CR_URL,
            )
            if previous is not None:
                previous.superseded_by = version
                previous.save(update_fields=["superseded_by"])
            previous = version
        guideline.current_version = previous
        guideline.status = status
        guideline.save(update_fields=["current_version", "status"])
    return guidelines


def attach_to_demo_lesson(guideline: ClinicalGuideline) -> bool:
    """Добавляет в демо-урок об аппендиците ссылки на код и КР, если их ещё нет."""
    lesson = (
        Lesson.objects.filter(topic__slug="appendicitis", slug="diagnosis").select_related("published_revision").first()
    )
    revision = lesson and lesson.published_revision
    if revision is None or any(b.get("type") == "guideline_ref" for b in revision.body):
        return False
    revision.body = [
        *revision.body,
        {"type": "heading", "text": "Справочники"},
        {"type": "icd_ref", "code": "K35"},
        {"type": "guideline_ref", "guideline_id": guideline.pk},
    ]
    revision.save(update_fields=["body"])
    return True
