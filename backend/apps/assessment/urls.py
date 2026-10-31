from django.urls import path

from . import views

urlpatterns = [
    path("quizzes/<int:quiz_id>/attempts", views.QuizAttemptsView.as_view(), name="quiz-attempts"),
    path("attempts/<uuid:attempt_id>/answers", views.AttemptAnswerView.as_view(), name="attempt-answers"),
    path("attempts/<uuid:attempt_id>/finish", views.AttemptFinishView.as_view(), name="attempt-finish"),
    path("attempts/<uuid:attempt_id>/review", views.AttemptReviewView.as_view(), name="attempt-review"),
]
