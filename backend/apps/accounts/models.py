import secrets
import uuid

from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


class User(AbstractUser):
    """커스텀 User.

    필드는 앞으로 늘어나도 되지만(평범한 마이그레이션),
    AUTH_USER_MODEL 교체 자체는 최초 migrate 이후에 불가능하다.
    그래서 프로젝트 시작 시점에 미리 만들어 둔다.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    class Meta:
        db_table = "user"


def generate_invitation_code() -> str:
    return secrets.token_hex(6).upper()  # 12자리


class Invitation(models.Model):
    """의료진 발급식 회원가입 초대코드.

    dept_code/position_code는 설계문서 6.2절 기준이지만, 코드 테이블
    (department/job_group/position)은 3단계에서 만들 예정이라 아직 없다.
    그래서 지금은 apps.staff.Staff와 동일한 role/department 필드로
    단순화해뒀다 — 3단계에서 코드 테이블이 생기면 그쪽으로 이관.
    """

    code = models.CharField(
        max_length=12, primary_key=True, default=generate_invitation_code
    )
    issued_by = models.ForeignKey(
        "staff.Staff", on_delete=models.PROTECT, related_name="invitations_issued"
    )
    role = models.CharField(max_length=20)  # apps.staff.Staff.Role 값 중 하나
    department = models.CharField(max_length=100, blank=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    used_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="+",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "invitation"

    def is_valid(self) -> bool:
        return not self.is_used and self.expires_at > timezone.now()
