from apps.assessment import selectors as assessment
from apps.content import selectors as content

from .models import LessonProgress, TopicMastery

# Тема «освоена» при освоении ≥ 0,8 и ≥ 10 ответах.
MASTERED_AT = 0.8
MASTERED_MIN_ANSWERS = 10

# Работа над ошибками открывается после 5 ошибок в дисциплине (docs/05-learning.md, 5.3).
MISTAKES_MIN = 5


def topic_mastery(user, topic_ids):
    return {m.topic_id: m for m in TopicMastery.objects.filter(user=user, topic_id__in=topic_ids)}


def discipline_mastery(topics, mastery, question_counts) -> float:
    """Среднее освоение тем, взвешенное по числу вопросов; темы без вопросов не учитываются."""
    weighted = [
        (question_counts.get(t.pk, 0), float(mastery[t.pk].mastery) if t.pk in mastery else 0.0) for t in topics
    ]
    total = sum(w for w, _ in weighted)
    return round(sum(w * m for w, m in weighted) / total, 3) if total else 0.0


def disciplines_overview(user):
    disciplines = list(content.disciplines_with_topics())
    topic_ids = [t.pk for d in disciplines for t in d.published_topics]
    mastery = topic_mastery(user, topic_ids)
    counts = assessment.published_question_counts(topic_ids)
    return [
        {
            "slug": d.slug,
            "title": d.title,
            "palette_token": d.palette_token,
            "is_premium": d.is_premium,
            "topics_count": len(d.published_topics),
            "mastery": discipline_mastery(d.published_topics, mastery, counts),
        }
        for d in disciplines
    ]


def discipline_detail(user, slug):
    discipline = content.published_discipline(slug)
    topics = list(content.published_topics(discipline=discipline).order_by("sort_order"))
    topic_ids = [t.pk for t in topics]
    lessons = list(content.published_lessons(topic_id__in=topic_ids))
    done = set(LessonProgress.objects.filter(user=user, lesson__in=lessons).values_list("lesson_id", flat=True))
    quizzes = assessment.topic_quizzes(topic_ids)
    mastery = topic_mastery(user, topic_ids)
    return {
        "slug": discipline.slug,
        "title": discipline.title,
        "palette_token": discipline.palette_token,
        "topics": [
            {
                "id": t.pk,
                "title": t.title,
                "is_premium": t.is_premium,
                "mastery": float(mastery[t.pk].mastery) if t.pk in mastery else 0.0,
                "mastered": t.pk in mastery
                and mastery[t.pk].mastery >= MASTERED_AT
                and mastery[t.pk].answered >= MASTERED_MIN_ANSWERS,
                "lessons": [
                    {
                        "id": lesson.pk,
                        "title": lesson.published_revision.title,
                        "minutes": lesson.published_revision.estimated_minutes,
                        "completed": lesson.pk in done,
                    }
                    for lesson in lessons
                    if lesson.topic_id == t.pk
                ],
                "quiz": (
                    {
                        "id": quizzes[t.pk].pk,
                        "questions": min(quizzes[t.pk].question_count, quizzes[t.pk].published_questions),
                    }
                    if t.pk in quizzes
                    else None
                ),
            }
            for t in topics
        ],
    }


def weakest_topic(user):
    """Тема с наименьшим освоением среди тех, где уже есть ответы."""
    return (
        TopicMastery.objects.filter(user=user, answered__gt=0)
        .select_related("topic__discipline")
        .order_by("mastery", "-updated_at")
        .first()
    )


def last_unfinished_lesson(user):
    """«Продолжить»: первый непройденный урок в теме последнего пройденного урока, иначе первый урок каталога."""
    done = set(LessonProgress.objects.filter(user=user).values_list("lesson_id", flat=True))
    last = LessonProgress.objects.filter(user=user).order_by("-completed_at").select_related("lesson").first()
    candidates = content.published_lessons().select_related("topic__discipline")
    if last:
        same_topic = candidates.filter(topic_id=last.lesson.topic_id).exclude(pk__in=done).first()
        if same_topic:
            return same_topic
    return (
        candidates.exclude(pk__in=done)
        .order_by("topic__discipline__sort_order", "topic__sort_order", "sort_order")
        .first()
    )


def lessons_completed_count(user) -> int:
    return LessonProgress.objects.filter(user=user).count()


def practice_overview(user):
    """Вкладка «Практика»: дисциплины, где есть вопросы, — с числом вопросов и ошибок."""
    disciplines = list(content.published_disciplines().order_by("sort_order"))
    ids = [d.pk for d in disciplines]
    questions = assessment.discipline_question_counts(ids)
    mistakes = assessment.mistakes(user, ids)
    return [
        {
            "slug": d.slug,
            "title": d.title,
            "palette_token": d.palette_token,
            "questions": questions[d.pk],
            "mistakes": len(mistakes.get(d.pk, [])),
            "mistakes_available": len(mistakes.get(d.pk, [])) >= MISTAKES_MIN,
        }
        for d in disciplines
        if questions.get(d.pk)
    ]
