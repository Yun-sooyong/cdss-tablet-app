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
        "batches/<uuid:batch_id>/",
        views.BatchDetailView.as_view(),
        name="batch-detail",
    ),
    path(
        "batches/<uuid:batch_id>/images/",
        views.BatchImageUploadView.as_view(),
        name="batch-image-upload",
    ),
    path(
        "batches/<uuid:batch_id>/start/",
        views.BatchStartView.as_view(),
        name="batch-start",
    ),
    path(
        "batches/<uuid:batch_id>/shares/",
        views.BatchShareListCreateView.as_view(),
        name="batch-share-list-create",
    ),
    path("shares/", views.AnalysisShareListView.as_view(), name="share-list"),
    path(
        "shares/<uuid:share_id>/",
        views.ShareRevokeView.as_view(),
        name="share-revoke",
    ),
    path(
        "images/<uuid:image_id>/jobs/",
        views.ImageJobCreateView.as_view(),
        name="image-job-create",
    ),
    path("jobs/", views.JobListView.as_view(), name="job-list"),
    path("jobs/<uuid:job_id>/", views.JobDetailView.as_view(), name="job-detail"),
    path(
        "jobs/<uuid:job_id>/callback/",
        views.JobCallbackView.as_view(),
        name="job-callback",
    ),
    path(
        "internal/workers/heartbeat/",
        views.WorkerHeartbeatView.as_view(),
        name="worker-heartbeat",
    ),
]
