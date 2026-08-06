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
    path("visits/", views.StaffVisitCreateView.as_view(), name="staff-visit-create"),
    path(
        "visits/<uuid:visit_id>/",
        views.VisitDetailView.as_view(),
        name="visit-detail",
    ),
    path(
        "prescriptions/",
        views.StaffPrescriptionCreateView.as_view(),
        name="staff-prescription-create",
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
    path(
        "medications/logs/<uuid:schedule_id>/",
        views.MedicationLogDeleteView.as_view(),
        name="medication-log-delete",
    ),
]
