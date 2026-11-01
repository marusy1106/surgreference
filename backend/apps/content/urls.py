from django.urls import path

from . import views

urlpatterns = [
    path("lessons/<int:lesson_id>", views.LessonView.as_view(), name="lesson"),
    path("icd10", views.ICD10ListView.as_view(), name="icd10"),
    path("icd10/<str:code>", views.ICD10DetailView.as_view(), name="icd10-code"),
    path("guidelines", views.GuidelineListView.as_view(), name="guidelines"),
    path("guidelines/<int:guideline_id>", views.GuidelineDetailView.as_view(), name="guideline"),
]
