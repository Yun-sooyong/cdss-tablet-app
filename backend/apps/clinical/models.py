import uuid

from django.conf import settings
from django.db import models

from apps.common.models import BaseModel
from apps.patients.models import Patient
from apps.staff.models import Department, Staff


class Reservation(BaseModel):
    """설계문서 6.5절. 다건 예약, 취소/변경 이력을 위해 별도 테이블로 둔다."""

    class Status(models.TextChoices):
        REQUESTED = "REQUESTED", "요청됨"
        CONFIRMED = "CONFIRMED", "확정"
        CHANGED = "CHANGED", "변경됨"
        CANCELED = "CANCELED", "취소됨"
        NO_SHOW = "NO_SHOW", "미방문"

    patient = models.ForeignKey(
        Patient, on_delete=models.CASCADE, related_name="reservations"
    )
    staff = models.ForeignKey(
        Staff,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reservations",
    )
    department = models.ForeignKey(
        Department, on_delete=models.PROTECT, related_name="reservations"
    )
    scheduled_at = models.DateTimeField()
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.REQUESTED
    )
    change_reason = models.CharField(max_length=200, blank=True)

    class Meta:
        db_table = "reservation"

    def __str__(self):
        return f"{self.patient_id} @ {self.scheduled_at}"


class ReservationHistory(models.Model):
    """예약 변경 이력 — 분쟁 시 감사 추적용. 설계문서 6.5절."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reservation = models.ForeignKey(
        Reservation, on_delete=models.CASCADE, related_name="history"
    )
    prev_scheduled_at = models.DateTimeField()
    new_scheduled_at = models.DateTimeField()
    changed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True
    )
    changed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "reservation_history"


class Disease(models.Model):
    """병명 코드 테이블. 설계문서 6.5절 — KCD/ICD-10 표준코드 사용 권장."""

    code = models.CharField(max_length=10, primary_key=True)
    name_ko = models.CharField(max_length=100)
    name_en = models.CharField(max_length=100, blank=True)
    category_major = models.CharField(max_length=50, blank=True)
    category_middle = models.CharField(max_length=50, blank=True)
    category_minor = models.CharField(max_length=50, blank=True)

    class Meta:
        db_table = "disease"

    def __str__(self):
        return self.name_ko


class Visit(BaseModel):
    """진료. 설계문서 6.5절 — 같은 날 2회 진료 가능해서 (patient, visited_at)
    인덱스만 걸고 유니크 제약은 두지 않는다."""

    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name="visits")
    staff = models.ForeignKey(
        Staff, on_delete=models.SET_NULL, null=True, related_name="visits"
    )
    visited_at = models.DateTimeField()
    note = models.TextField(blank=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "visit"
        indexes = [models.Index(fields=["patient", "visited_at"])]

    def __str__(self):
        return f"{self.patient_id} @ {self.visited_at}"


class Diagnosis(models.Model):
    """진단. 진료 1:N 진단. 설계문서 6.5절."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    visit = models.ForeignKey(Visit, on_delete=models.CASCADE, related_name="diagnoses")
    disease = models.ForeignKey(
        Disease, on_delete=models.PROTECT, related_name="diagnoses"
    )
    is_primary = models.BooleanField(default=False)

    class Meta:
        db_table = "diagnosis"
