from django.urls import path

from . import views

urlpatterns = [
    path(
        "model-versions/",
        views.ModelVersionListView.as_view(),
        name="model-version-list",
    ),
    path("batches/", views.BatchListCreateView.as_view(), name="batch-list-create"),
    path(
        "batches/<uuid:batch_id>/images/",
        views.BatchImageUploadView.as_view(),
        name="batch-image-upload",
    ),
    path(
        "images/<uuid:image_id>/jobs/",
        views.ImageJobCreateView.as_view(),
        name="image-job-create",
    ),
    path("jobs/<uuid:job_id>/", views.JobDetailView.as_view(), name="job-detail"),
    path(
        "jobs/<uuid:job_id>/callback/",
        views.JobCallbackView.as_view(),
        name="job-callback",
    ),
]
