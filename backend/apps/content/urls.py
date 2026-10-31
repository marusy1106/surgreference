from django.urls import path

from . import views

urlpatterns = [
    path("lessons/<int:lesson_id>", views.LessonView.as_view(), name="lesson"),
]
