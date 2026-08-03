from django.urls import path

from apps.clinical.views import PatientReservationListCreateView

from . import views

urlpatterns = [
    path("me/", views.PatientMeView.as_view(), name="patient-me"),
    path(
        "me/reservations/",
        PatientReservationListCreateView.as_view(),
        name="patient-reservation-list-create",
    ),
]
