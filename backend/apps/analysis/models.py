from django.db import models

from apps.common.models import BaseModel
from apps.staff.models import Staff


class ModelVersion(BaseModel):
    name = models.CharField(max_length=100)
    version = models.CharField(max_length=50)
    conformal_q = models.FloatField()
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "model_version"
        unique_together = ("name", "version")

    def __str__(self):
        return f"{self.name}:{self.version}"


class Batch(BaseModel):
    class Status(models.TextChoices):
        PENDING = "pending", "대기"
        PROCESSING = "processing", "처리중"
        DONE = "done", "완료"
        FAILED = "failed", "실패"

    created_by = models.ForeignKey(
        Staff, on_delete=models.PROTECT, related_name="batches"
    )
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING
    )

    class Meta:
        db_table = "batch"


class Image(BaseModel):
    batch = models.ForeignKey(Batch, on_delete=models.CASCADE, related_name="images")
    storage_key = models.CharField(max_length=255)
    original_filename = models.CharField(max_length=255, blank=True)

    class Meta:
        db_table = "image"


class Job(BaseModel):
    class Status(models.TextChoices):
        QUEUED = "queued", "대기"
        RUNNING = "running", "실행중"
        SUCCEEDED = "succeeded", "성공"
        FAILED = "failed", "실패"

    image = models.ForeignKey(Image, on_delete=models.CASCADE, related_name="jobs")
    model_version = models.ForeignKey(
        ModelVersion, on_delete=models.PROTECT, related_name="jobs"
    )
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.QUEUED
    )
    result = models.JSONField(null=True, blank=True)
    error_message = models.TextField(blank=True)
    started_at = models.DateTimeField(null=True, blank=True)
    finished_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "job"
