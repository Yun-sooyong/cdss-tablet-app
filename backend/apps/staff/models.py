from django.conf import settings
from django.db import models

from apps.common.models import BaseModel


class Department(models.Model):
    """병원과 코드 테이블. 설계문서 6.4절.

    자연키(dept_code) PK — 공통 규칙(6.1): 코드성 테이블은 자연키 문자열 PK.
    """

    dept_code = models.CharField(max_length=6, primary_key=True)
    name = models.CharField(max_length=50)
    extension = models.CharField(max_length=10, blank=True)

    class Meta:
        db_table = "department"

    def __str__(self):
        return self.name


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
