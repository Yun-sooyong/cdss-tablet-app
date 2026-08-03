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
