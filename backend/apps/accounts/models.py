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


def generate_qr_token() -> str:
    return secrets.token_hex(32)  # 64자


class QRToken(models.Model):
    """환자 QR 발급/태블릿 검증. 설계문서 6.2절 — 일회성·단기 만료·재사용 차단
    없으면 화면 캡처만으로 타인이 환자 정보에 접근하게 된다."""

    token = models.CharField(max_length=64, primary_key=True, default=generate_qr_token)
    patient = models.ForeignKey(
        "patients.Patient", on_delete=models.CASCADE, related_name="qr_tokens"
    )
    issued_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    verified_by = models.ForeignKey(
        "staff.Staff",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="qr_verifications",
    )

    class Meta:
        db_table = "qr_token"

    def is_valid(self) -> bool:
        return not self.is_used and self.expires_at > timezone.now()


class DeviceToken(models.Model):
    """FCM 푸시용 디바이스 토큰. 설계문서 6.9절."""

    class Platform(models.TextChoices):
        IOS = "ios", "iOS"
        ANDROID = "android", "Android"
        WEB = "web", "Web"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="device_tokens"
    )
    fcm_token = models.CharField(max_length=255)
    platform = models.CharField(max_length=10, choices=Platform.choices)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "device_token"
        unique_together = ("user", "fcm_token")


class Notification(models.Model):
    """알림. 설계문서 6.9절 — 분석 완료 등 이벤트 시 생성, 실제 FCM 발송
    여부와 무관하게 기록은 항상 남긴다."""

    class Type(models.TextChoices):
        ANALYSIS_DONE = "analysis_done", "분석 완료"
        SHARE = "share", "공유"
        CHAT = "chat", "채팅"
        # 서정은 요청, 2026-08-05 — 환자용 알림 화면 만들 예정이라 환자
        # 쪽 이벤트도 최대한 커버
        RESERVATION_CONFIRMED = "reservation_confirmed", "예약 확정"
        VISIT_CREATED = "visit_created", "진료 기록 등록"
        PRESCRIPTION_CREATED = "prescription_created", "처방 등록"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications"
    )
    type = models.CharField(max_length=30, choices=Type.choices)
    body = models.CharField(max_length=255)
    target_type = models.CharField(max_length=50, blank=True)
    target_id = models.UUIDField(null=True, blank=True)
    is_read = models.BooleanField(default=False)
    sent_result = models.CharField(max_length=50, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "notification"
        ordering = ["-created_at"]


class AuditLog(models.Model):
    """접근 로그. 설계문서 6.9절/12장 — 의료 시스템은 조회 이력까지 남겨야
    유출 시 범위 파악이 가능하다 (법적 요구사항에 가까움)."""

    class Action(models.TextChoices):
        READ = "READ", "조회"
        CREATE = "CREATE", "생성"
        UPDATE = "UPDATE", "수정"
        DELETE = "DELETE", "삭제"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    actor_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="audit_logs",
    )
    action = models.CharField(max_length=10, choices=Action.choices)
    target_table = models.CharField(max_length=50)
    target_id = models.UUIDField(null=True, blank=True)
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="audit_logs",
    )
    ip = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "audit_log"
