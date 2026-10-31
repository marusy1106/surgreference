from django.urls import path

from . import views

urlpatterns = [
    path("disciplines", views.DisciplineListView.as_view(), name="disciplines"),
    path("disciplines/<slug:slug>", views.DisciplineDetailView.as_view(), name="discipline"),
    path("lessons/<int:lesson_id>/complete", views.LessonCompleteView.as_view(), name="lesson-complete"),
]
