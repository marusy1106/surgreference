from django.urls import path

from . import views

urlpatterns = [
    path("universities", views.UniversityListView.as_view(), name="universities"),
    path("universities/requests", views.UniversityRequestView.as_view(), name="university-requests"),
    path("universities/<int:university_id>/faculties", views.FacultyListView.as_view(), name="university-faculties"),
    path("specialties", views.SpecialtyListView.as_view(), name="specialties"),
    path("me/education", views.EducationView.as_view(), name="education"),
    path("me/education/history", views.EducationHistoryView.as_view(), name="education-history"),
]
