from django.urls import path

from apps.clinical.views import PatientReservationListCreateView, PatientVisitListView

from . import views

urlpatterns = [
    path("me/", views.PatientMeView.as_view(), name="patient-me"),
    path(
        "me/reservations/",
        PatientReservationListCreateView.as_view(),
        name="patient-reservation-list-create",
    ),
    path(
        "me/visits/",
        PatientVisitListView.as_view(),
        name="patient-visit-list",
    ),
]
