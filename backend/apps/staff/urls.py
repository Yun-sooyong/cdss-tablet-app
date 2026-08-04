from django.urls import path

from . import views

urlpatterns = [
    path("me/", views.StaffMeView.as_view(), name="staff-me"),
    path("", views.StaffListView.as_view(), name="staff-list"),
    path(
        "<uuid:staff_id>/",
        views.StaffDeactivateView.as_view(),
        name="staff-deactivate",
    ),
]
