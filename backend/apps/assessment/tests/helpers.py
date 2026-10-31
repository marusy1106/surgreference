from apps.assessment.models import AnswerOption, Quiz


def demo_quiz():
    return Quiz.objects.get(title="Острый аппендицит")


def correct_ids(question_id):
    return list(AnswerOption.objects.filter(question_id=question_id, is_correct=True).values_list("pk", flat=True))


def wrong_id(question_id):
    return AnswerOption.objects.filter(question_id=question_id, is_correct=False).values_list("pk", flat=True).first()


def run_quiz(client, *, right: int):
    """Пройти демо-тест: первые `right` вопросов верно, остальные — неверно. Возвращает (старт, финиш)."""
    started = client.post(f"/api/v1/quizzes/{demo_quiz().pk}/attempts").json()
    for i, question in enumerate(started["questions"]):
        ids = correct_ids(question["id"]) if i < right else [wrong_id(question["id"])]
        response = client.post(
            f"/api/v1/attempts/{started['attempt_id']}/answers",
            {"question_id": question["id"], "option_ids": ids},
            format="json",
        )
        assert response.status_code == 204, response.json()
    finished = client.post(f"/api/v1/attempts/{started['attempt_id']}/finish").json()
    return started, finished
