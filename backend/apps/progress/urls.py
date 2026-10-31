from django.urls import path

from . import views

urlpatterns = [
    path("disciplines", views.DisciplineListView.as_view(), name="disciplines"),
    path("disciplines/<slug:slug>", views.DisciplineDetailView.as_view(), name="discipline"),
    path("disciplines/<slug:slug>/training", views.TrainingView.as_view(), name="discipline-training"),
    path("disciplines/<slug:slug>/mistakes", views.MistakesView.as_view(), name="discipline-mistakes"),
    path("practice", views.PracticeView.as_view(), name="practice"),
    path("lessons/<int:lesson_id>/complete", views.LessonCompleteView.as_view(), name="lesson-complete"),
]
