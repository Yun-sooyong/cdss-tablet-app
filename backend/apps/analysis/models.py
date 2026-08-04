from django.db import models

from apps.common.models import BaseModel
from apps.patients.models import Patient
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
    # 설계문서 2.6/3.2-j — batch에 환자 FK 연결. 기존(이 필드 추가 전) 테스트
    # batch가 이미 있어서 null=True로 둔다 — API 생성 시엔 필수로 강제한다.
    patient = models.ForeignKey(
        Patient, on_delete=models.PROTECT, null=True, blank=True, related_name="batches"
    )
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING
    )
    deleted_at = models.DateTimeField(null=True, blank=True)  # soft delete, 3.2-i

    class Meta:
        db_table = "batch"


class Image(BaseModel):
    batch = models.ForeignKey(Batch, on_delete=models.CASCADE, related_name="images")
    storage_key = models.CharField(max_length=255)
    original_filename = models.CharField(max_length=255, blank=True)
    captured_at = models.DateTimeField(null=True, blank=True)
    width = models.IntegerField(null=True, blank=True)
    height = models.IntegerField(null=True, blank=True)

    class Meta:
        db_table = "image"


class Job(BaseModel):
    class Status(models.TextChoices):
        QUEUED = "queued", "대기"
        RUNNING = "running", "실행중"
        STIL_DONE = "stil_done", "sTIL 완료 (리포트 대기)"
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


class AnalysisShare(BaseModel):
    """분석 결과 공유. 설계문서 6.7절 — 「본인이 분석한 내용만 표시」와
    「다른 유저도 확인할 수 있도록 공유」를 동시에 만족시키는 조회 권한 기준."""

    class Permission(models.TextChoices):
        READ = "read", "읽기"
        COMMENT = "comment", "댓글"

    batch = models.ForeignKey(Batch, on_delete=models.CASCADE, related_name="shares")
    shared_by = models.ForeignKey(
        Staff, on_delete=models.CASCADE, related_name="shares_given"
    )
    shared_to = models.ForeignKey(
        Staff, on_delete=models.CASCADE, related_name="shares_received"
    )
    permission = models.CharField(
        max_length=10, choices=Permission.choices, default=Permission.READ
    )
    expires_at = models.DateTimeField(null=True, blank=True)  # NULL이면 무기한
    revoked_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "analysis_share"


class WorkerHeartbeat(models.Model):
    """워커 생존 관리. 설계문서 6.9절/2.5절 — N분 이상 끊기면 알림 (모니터링은
    별도 과제, 여기서는 최신 생존 시각만 기록)."""

    worker_name = models.CharField(max_length=50, primary_key=True)
    last_seen_at = models.DateTimeField(auto_now=True)
    version = models.CharField(max_length=20, blank=True)

    class Meta:
        db_table = "worker_heartbeat"
