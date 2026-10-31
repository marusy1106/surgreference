from .models import CaseChoiceQuality

GOOD = {CaseChoiceQuality.OPTIMAL, CaseChoiceQuality.ACCEPTABLE}


def case_header(case):
    return {
        "id": case.pk,
        "title": case.title,
        "summary": case.summary,
        "discipline": case.discipline.title,
        "palette_token": case.discipline.palette_token,
        "difficulty": case.difficulty,
    }


def step_payload(step, number, total):
    """Шаг без качества вариантов и обратной связи — их клиент узнаёт после выбора."""
    content = step.content or {}
    return {
        "id": step.pk,
        "number": number,
        "total": total,
        "title": content.get("title", ""),
        "situation": content.get("situation", ""),
        "prompt": content.get("prompt", ""),
        "summary": content.get("summary", ""),
        "choices": [{"id": c.pk, "text": c.text} for c in step.choices.all()],
    }


def optimal_choice(step):
    return max(step.choices.all(), key=lambda c: c.score_delta)


def outcome_payload(choice, next_step, attempt, steps):
    numbers = {s.pk: i + 1 for i, s in enumerate(steps)}
    finished = next_step is None
    return {
        "choice_id": choice.pk,
        "quality": choice.quality,
        "is_good": choice.quality in GOOD,
        "feedback": choice.feedback,
        "optimal_choice_id": optimal_choice(choice.step).pk,
        "finished": finished,
        "next_step": None if finished else step_payload(next_step, numbers[next_step.pk], len(steps)),
        "score": float(attempt.score) if finished else None,
        "xp_awarded": attempt.xp_awarded if finished else None,
    }


def review_payload(attempt, path):
    return {
        "attempt_id": str(attempt.pk),
        "case": case_header(attempt.case),
        "score": float(attempt.score or 0),
        "xp_awarded": attempt.xp_awarded,
        "debrief": attempt.case.debrief,
        "disclaimer": "Учебный кейс. Пациент вымышлен. Не является руководством к лечению.",
        "steps": [
            {
                "title": (choice.step.content or {}).get("title", ""),
                "summary": (choice.step.content or {}).get("summary", ""),
                "chosen": {
                    "text": choice.text,
                    "quality": choice.quality,
                    "is_good": choice.quality in GOOD,
                    "feedback": choice.feedback,
                },
                "optimal": {"text": optimal_choice(choice.step).text},
            }
            for choice in path
        ],
    }
