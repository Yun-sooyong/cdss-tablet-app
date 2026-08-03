from django.conf import settings
from django.db import models

from apps.common.models import BaseModel


class Staff(BaseModel):
    class Role(models.TextChoices):
        DOCTOR = "doctor", "의사"
        NURSE = "nurse", "간호사"
        ADMIN = "admin", "관리자"

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="staff"
    )
    role = models.CharField(max_length=20, choices=Role.choices)
    department = models.CharField(max_length=100, blank=True)

    class Meta:
        db_table = "staff"

    def __str__(self):
        return f"{self.user.username} ({self.role})"
