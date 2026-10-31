from django.urls import path

from . import views

urlpatterns = [
    path("leaderboards/users", views.UserBoardView.as_view(), name="leaderboard-users"),
    path("leaderboards/universities", views.UniversityBoardView.as_view(), name="leaderboard-universities"),
    path("me/leaderboard-participation", views.ParticipationView.as_view(), name="me-leaderboard-participation"),
]
