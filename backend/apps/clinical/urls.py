from django.urls import path

from . import views

urlpatterns = [
    path(
        "reservations/<uuid:reservation_id>/",
        views.ReservationDetailView.as_view(),
        name="reservation-detail",
    ),
    path(
        "visits/<uuid:visit_id>/",
        views.VisitDetailView.as_view(),
        name="visit-detail",
    ),
]
