from django.urls import path

from . import views

urlpatterns = [
    path("me/progress", views.ProgressView.as_view(), name="me-progress"),
    path("me/activity", views.ActivityView.as_view(), name="me-activity"),
    path("me/achievements", views.AchievementsView.as_view(), name="me-achievements"),
]
