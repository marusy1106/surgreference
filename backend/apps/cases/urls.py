from django.urls import path

from . import views

urlpatterns = [
    path("cases", views.CaseListView.as_view(), name="cases"),
    path("cases/<int:case_id>/attempts", views.CaseAttemptsView.as_view(), name="case-attempts"),
    path("case-attempts/<uuid:attempt_id>/choices", views.CaseChoiceView.as_view(), name="case-choices"),
    path("case-attempts/<uuid:attempt_id>/review", views.CaseReviewView.as_view(), name="case-review"),
]
