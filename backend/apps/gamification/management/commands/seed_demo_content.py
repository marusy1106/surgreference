"""Демо-контент для разработки и бета-проверки: дисциплины, тема «Острый аппендицит» (урок, тест из 5 вопросов),
клинический кейс. Пользователи-авторы неактивны и не могут войти. Повторный запуск ничего не дублирует.

Модуль gamification выбран как самый верхний слой, которому разрешено знать про контент, тесты и кейсы."""

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.contenttypes.models import ContentType
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from apps.assessment.models import AnswerOption, Question, QuestionKind, Quiz, QuizQuestion
from apps.cases.models import CaseChoice, CaseChoiceQuality, CaseStep, CaseStepKind, ClinicalCase
from apps.content.models import (
    CatalogStatus,
    ContentSource,
    Discipline,
    Lesson,
    LessonRevision,
    ReviewStatus,
    Source,
    SourceKind,
    SourceLicense,
    Topic,
)

DISCIPLINES = [
    ("surgery", "Хирургия"),
    ("therapy", "Терапия"),
    ("cardiology", "Кардиология"),
    ("neurology", "Неврология"),
    ("pediatrics", "Педиатрия"),
    ("pharmacology", "Фармакология"),
]

LESSON_BODY = [
    {
        "type": "paragraph",
        "text": "Острый аппендицит — самое частое острое хирургическое заболевание органов брюшной полости. "
        "Диагноз ставится прежде всего клинически, инструментальные методы его подтверждают.",
    },
    {"type": "heading", "text": "Типичная клиническая картина"},
    {
        "type": "list",
        "items": [
            "Боль начинается в эпигастрии или около пупка и через несколько часов смещается в правую подвздошную "
            "область (симптом Кохера).",
            "Тошнота, однократная рвота, снижение аппетита.",
            "Субфебрильная температура, умеренный лейкоцитоз.",
        ],
    },
    {
        "type": "callout",
        "text": "У беременных, пожилых и детей картина часто стёрта. Сомнение в диагнозе — повод для динамического "
        "наблюдения и визуализации.",
    },
    {
        "type": "table",
        "caption": "Шкала Альварадо",
        "header": ["Признак", "Баллы"],
        "rows": [
            ["Миграция боли в правую подвздошную область", "1"],
            ["Анорексия", "1"],
            ["Тошнота или рвота", "1"],
            ["Болезненность в правой подвздошной области", "2"],
            ["Симптом раздражения брюшины", "1"],
            ["Температура выше 37,3 °C", "1"],
            ["Лейкоцитоз", "2"],
            ["Сдвиг лейкоцитарной формулы влево", "1"],
        ],
    },
]

# (условие, тип, [(вариант, верно, объяснение)], общий разбор)
QUESTIONS = [
    (
        "Как называется смещение боли из эпигастрия в правую подвздошную область?",
        QuestionKind.SINGLE,
        [
            ("Симптом Кохера", True, "Кохер (Кохер — Волкович) — миграция боли в первые часы заболевания."),
            (
                "Симптом Ровзинга",
                False,
                "Ровзинг — боль справа при толчкообразном давлении в левой подвздошной области.",
            ),
            (
                "Симптом Щёткина — Блюмберга",
                False,
                "Это усиление боли при резком отнятии руки — признак раздражения брюшины.",
            ),
            (
                "Симптом Ортнера",
                False,
                "Ортнер — болезненность при поколачивании по правой рёберной дуге, признак холецистита.",
            ),
        ],
        "Миграцию боли из эпигастрия в правую подвздошную область называют симптомом Кохера.",
    ),
    (
        "Что такое симптом Ровзинга?",
        QuestionKind.SINGLE,
        [
            (
                "Боль справа при толчкообразном давлении в левой подвздошной области",
                True,
                "Это и есть симптом Ровзинга.",
            ),
            ("Усиление боли при резком отнятии руки от брюшной стенки", False, "Это симптом Щёткина — Блюмберга."),
            ("Усиление боли в положении на левом боку", False, "Это симптом Ситковского."),
            ("Боль при поднятии выпрямленной правой ноги", False, "Это симптом Образцова."),
        ],
        "Ровзинг — боль в правой подвздошной области при толчкообразном давлении слева.",
    ),
    (
        "Какой метод визуализации выбирают первым при подозрении на аппендицит у беременной?",
        QuestionKind.SINGLE,
        [
            (
                "КТ брюшной полости с контрастированием",
                False,
                "КТ у беременных применяют ограниченно из-за лучевой нагрузки.",
            ),
            ("УЗИ брюшной полости", True, "Метод первой линии: нет лучевой нагрузки на плод."),
            ("Обзорная рентгенография", False, "Малоинформативна для диагностики аппендицита и даёт лучевую нагрузку."),
        ],
        "Если УЗИ не дало ответа, следующим выполняют МРТ без контрастирования.",
    ),
    (
        "Сколько баллов шкалы Альварадо даёт лейкоцитоз?",
        QuestionKind.SINGLE,
        [
            ("1", False, "По 1 баллу дают шесть других признаков."),
            ("2", True, "Лейкоцитоз и болезненность в правой подвздошной области — по 2 балла."),
            ("3", False, "Признаков с весом 3 в шкале нет."),
        ],
        "Максимум по шкале — 10 баллов.",
    ),
    (
        "Какие признаки входят в шкалу Альварадо?",
        QuestionKind.MULTIPLE,
        [
            ("Миграция боли в правую подвздошную область", True, "Входит, 1 балл."),
            ("Брадикардия", False, "Частота пульса в шкалу не входит."),
            ("Тошнота или рвота", True, "Входит, 1 балл."),
            ("Лейкоцитоз", True, "Входит, 2 балла."),
        ],
        "В шкалу входят восемь признаков: симптомы, данные осмотра и анализ крови.",
    ),
]

# (заголовок, ситуация, вопрос, краткая запись, [(вариант, качество, баллы, обратная связь)])
CASE_STEPS = [
    (
        "Жалобы и анамнез",
        "Пациент М., 24 года (вымышленный). С вечера тупая боль около пупка, к утру сместилась в правую "
        "подвздошную область. Тошнота, однократная рвота.",
        "С чего начнёте?",
        "Боль около пупка с вечера, к утру сместилась вправо вниз. Тошнота, рвота.",
        [
            (
                "Осмотр живота и измерение температуры",
                CaseChoiceQuality.OPTIMAL,
                2,
                "Миграция боли с тошнотой — типичное начало аппендицита. Следующий шаг — объективный осмотр.",
            ),
            (
                "Отпустить домой под наблюдение",
                CaseChoiceQuality.DANGEROUS,
                -2,
                "Картина типична для острого аппендицита: без осмотра отпускать нельзя.",
            ),
            (
                "Сразу направить на гастроскопию",
                CaseChoiceQuality.WRONG,
                0,
                "Жалобы указывают на правую подвздошную область, а не на верхние отделы ЖКТ.",
            ),
        ],
    ),
    (
        "Осмотр",
        "Температура 37,8 °C. Болезненность и напряжение мышц в правой подвздошной области, симптом "
        "Щёткина — Блюмберга положителен.",
        "Какое обследование назначите?",
        "Температура 37,8 °C, болезненность справа внизу, симптом Щёткина — Блюмберга +.",
        [
            (
                "Общий анализ крови и УЗИ брюшной полости",
                CaseChoiceQuality.OPTIMAL,
                2,
                "Анализ крови и УЗИ подтверждают диагноз и помогают исключить другую патологию.",
            ),
            (
                "Колоноскопию",
                CaseChoiceQuality.WRONG,
                0,
                "При подозрении на острый аппендицит колоноскопия не показана: она не помогает диагнозу.",
            ),
            (
                "Только ЭКГ",
                CaseChoiceQuality.WRONG,
                0,
                "ЭКГ не ответит на главный вопрос — есть ли острая хирургическая патология.",
            ),
        ],
    ),
    (
        "Обследование",
        "Лейкоциты 14 × 10⁹/л, сдвиг формулы влево. На УЗИ — несжимаемый червеобразный отросток диаметром 9 мм.",
        "Ваше решение?",
        "Лейкоцитоз со сдвигом влево, на УЗИ — утолщённый несжимаемый отросток.",
        [
            (
                "Госпитализация в хирургию и аппендэктомия",
                CaseChoiceQuality.OPTIMAL,
                2,
                "Диагноз подтверждён — показана операция. Лапароскопический доступ предпочтителен.",
            ),
            (
                "Антибиотики амбулаторно",
                CaseChoiceQuality.WRONG,
                0,
                "Консервативное лечение обсуждают только в стационаре и у отобранных пациентов.",
            ),
            (
                "Повторить УЗИ через неделю",
                CaseChoiceQuality.DANGEROUS,
                -2,
                "Отсрочка при остром аппендиците повышает риск перфорации и перитонита.",
            ),
        ],
    ),
]


class Command(BaseCommand):
    help = "Заполнить базу демо-контентом (только для разработки)"

    def add_arguments(self, parser):
        parser.add_argument("--force", action="store_true", help="Разрешить запуск при DEBUG=False")

    def handle(self, *args, force=False, **options):
        if not settings.DEBUG and not force:
            raise CommandError("Демо-контент не для продакшена. Если это стенд для беты — добавьте --force.")
        with transaction.atomic():
            created = self._seed()
        self.stdout.write(self.style.SUCCESS("Демо-контент создан." if created else "Демо-контент уже есть."))

    def _staff(self, email, name):
        user, _ = get_user_model().objects.get_or_create(
            email=email,
            defaults={"display_name": name, "first_name": name, "is_active": False},
        )
        if user.has_usable_password():
            user.set_unusable_password()
            user.save(update_fields=["password"])
        return user

    def _seed(self) -> bool:
        author = self._staff("demo-author@surgreference.invalid", "демо-автор")
        reviewer = self._staff("demo-reviewer@surgreference.invalid", "демо-рецензент")
        now = timezone.now()
        reviewed = {"author": author, "reviewer": reviewer, "reviewed_at": now, "published_at": now}

        disciplines = {}
        for order, (slug, title) in enumerate(DISCIPLINES):
            disciplines[slug], _ = Discipline.objects.get_or_create(
                slug=slug,
                defaults={
                    "title": title,
                    "palette_token": slug,
                    "sort_order": order,
                    "status": CatalogStatus.PUBLISHED,
                },
            )
        surgery = disciplines["surgery"]
        topic, created = Topic.objects.get_or_create(
            discipline=surgery,
            slug="appendicitis",
            defaults={"title": "Острый аппендицит", "sort_order": 0, "status": CatalogStatus.PUBLISHED},
        )
        if not created:
            return False
        for order, (slug, title) in enumerate(
            [("cholecystitis", "Острый холецистит"), ("hernia", "Ущемлённая грыжа")], 1
        ):
            Topic.objects.get_or_create(
                discipline=surgery,
                slug=slug,
                defaults={"title": title, "sort_order": order, "status": CatalogStatus.PUBLISHED},
            )

        lesson = Lesson.objects.create(topic=topic, slug="diagnosis")
        revision = LessonRevision.objects.create(
            lesson=lesson,
            version=1,
            title="Острый аппендицит: клиническая картина и диагностика",
            body=LESSON_BODY,
            estimated_minutes=7,
            status=ReviewStatus.PUBLISHED,
            publisher=reviewer,
            **reviewed,
        )
        lesson.published_revision = revision
        lesson.save(update_fields=["published_revision"])
        source, _ = Source.objects.get_or_create(
            title="Клинические рекомендации Минздрава России «Острый аппендицит у взрослых»",
            defaults={"kind": SourceKind.CLINICAL_GUIDELINE, "license": SourceLicense.CITATION},
        )
        ContentSource.objects.create(
            content_type=ContentType.objects.get_for_model(LessonRevision), object_id=revision.pk, source=source
        )

        quiz = Quiz.objects.create(
            discipline=surgery,
            topic=topic,
            title="Острый аппендицит",
            question_count=len(QUESTIONS),
            status=CatalogStatus.PUBLISHED,
        )
        for order, (text, kind, options, explanation) in enumerate(QUESTIONS):
            question = Question.objects.create(
                topic=topic,
                kind=kind,
                stem=[{"type": "paragraph", "text": text}],
                explanation=explanation,
                status=ReviewStatus.PUBLISHED,
                **reviewed,
            )
            AnswerOption.objects.bulk_create(
                AnswerOption(question=question, text=t, is_correct=ok, explanation=why, sort_order=i)
                for i, (t, ok, why) in enumerate(options)
            )
            QuizQuestion.objects.create(quiz=quiz, question=question, sort_order=order)

        case = ClinicalCase.objects.create(
            discipline=surgery,
            title="Боль в правой подвздошной области",
            summary="Молодой пациент с болью в животе: от жалоб до решения об операции.",
            debrief="Оптимальный путь: осмотр и термометрия → общий анализ крови и УЗИ → госпитализация и "
            "аппендэктомия, предпочтительно лапароскопическая. Повторите урок «Острый аппендицит: клиническая "
            "картина и диагностика».",
            status=ReviewStatus.PUBLISHED,
            synthetic_attested_by=reviewer,
            **reviewed,
        )
        for order, (title, situation, prompt, summary, choices) in enumerate(CASE_STEPS):
            step = CaseStep.objects.create(
                case=case,
                sort_order=order,
                kind=CaseStepKind.DECISION,
                content={"title": title, "situation": situation, "prompt": prompt, "summary": summary},
            )
            CaseChoice.objects.bulk_create(
                CaseChoice(step=step, text=t, quality=q, score_delta=d, feedback=f, sort_order=i)
                for i, (t, q, d, f) in enumerate(choices)
            )
        return True
