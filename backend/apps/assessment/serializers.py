from rest_framework import serializers

from .selectors import stem_text

DEFAULT_SECONDS_PER_QUESTION = 90


class AnswerInputSerializer(serializers.Serializer):
    question_id = serializers.IntegerField()
    option_ids = serializers.ListField(child=serializers.IntegerField(), max_length=10)


def _options_in_attempt_order(row):
    by_id = {o.pk: o for o in row.question.options.all()}
    return [by_id[i] for i in row.option_order if i in by_id]


def _quiz_header(attempt):
    quiz = attempt.quiz
    return {
        "id": quiz.pk,
        "title": quiz.title,
        "topic": quiz.topic.title if quiz.topic_id else "",
        "discipline_slug": attempt.discipline.slug,
        "palette_token": attempt.discipline.palette_token,
    }


def attempt_payload(attempt, rows):
    """Вопросы попытки без признаков правильности."""
    limit = attempt.quiz.time_limit_sec
    return {
        "attempt_id": str(attempt.pk),
        "quiz": _quiz_header(attempt),
        "seconds_per_question": limit // max(len(rows), 1) if limit else DEFAULT_SECONDS_PER_QUESTION,
        "questions": [
            {
                "id": row.question_id,
                "kind": row.question.kind,
                "text": stem_text(row.question.stem),
                "options": [{"id": o.pk, "text": o.text} for o in _options_in_attempt_order(row)],
            }
            for row in rows
        ],
    }


def result_payload(attempt):
    return {
        "attempt_id": str(attempt.pk),
        "correct": attempt.correct_count,
        "total": attempt.total_count,
        "score": float(attempt.score or 0),
        "xp_awarded": attempt.xp_awarded,
    }


def review_payload(attempt, rows, lesson_id):
    return {
        **result_payload(attempt),
        "quiz": _quiz_header(attempt),
        "lesson_id": lesson_id,
        "items": [
            {
                "question_id": row.question_id,
                "kind": row.question.kind,
                "text": stem_text(row.question.stem),
                "is_correct": bool(row.is_correct),
                "explanation": row.question.explanation,
                "options": [
                    {
                        "id": o.pk,
                        "text": o.text,
                        "is_correct": o.is_correct,
                        "selected": o.pk in row.selected_option_ids,
                        "explanation": o.explanation,
                    }
                    for o in _options_in_attempt_order(row)
                ],
            }
            for row in rows
        ],
    }
