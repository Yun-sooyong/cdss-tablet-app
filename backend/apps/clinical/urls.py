from django.urls import path

from . import views

urlpatterns = [
    path(
        "reservations/",
        views.StaffReservationListView.as_view(),
        name="staff-reservation-list",
    ),
    path(
        "reservations/<uuid:reservation_id>/",
        views.ReservationDetailView.as_view(),
        name="reservation-detail",
    ),
    path(
        "reservations/<uuid:reservation_id>/confirm/",
        views.ReservationConfirmView.as_view(),
        name="reservation-confirm",
    ),
    path(
        "visits/<uuid:visit_id>/",
        views.VisitDetailView.as_view(),
        name="visit-detail",
    ),
    path(
        "prescriptions/<uuid:prescription_id>/",
        views.PrescriptionDetailView.as_view(),
        name="prescription-detail",
    ),
    path(
        "medications/logs/",
        views.MedicationLogCreateView.as_view(),
        name="medication-log-create",
    ),
]
