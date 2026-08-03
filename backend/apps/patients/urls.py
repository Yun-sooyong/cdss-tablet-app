from django.urls import path

from . import views

urlpatterns = [
    path("me/", views.PatientMeView.as_view(), name="patient-me"),
]
