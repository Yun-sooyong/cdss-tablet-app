from django.urls import path

from apps.accounts.views import PatientQRIssueView
from apps.clinical.views import (
    PatientMedicationScheduleView,
    PatientPrescriptionListView,
    PatientReservationListCreateView,
    PatientVisitListView,
)

from . import views

urlpatterns = [
    path("register/", views.PatientRegisterView.as_view(), name="patient-register"),
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
    path(
        "me/prescriptions/",
        PatientPrescriptionListView.as_view(),
        name="patient-prescription-list",
    ),
    path(
        "me/medications/schedule/",
        PatientMedicationScheduleView.as_view(),
        name="patient-medication-schedule",
    ),
    path(
        "me/qr/",
        PatientQRIssueView.as_view(),
        name="patient-qr-issue",
    ),
]
