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
    # 초대코드 흐름은 계정발급신청(AccountRequest) API로 대체되어 Invitation
    # 모델은 삭제됐지만(마이그레이션 0006), 과거 마이그레이션
    # (0002_invitation.py)이 이 함수를 직접 참조하고 있어 재생성 시 깨지지
    # 않도록 남겨둔다.
    return secrets.token_hex(6).upper()  # 12자리


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
        # 최일운 요청, 2026-08-05 — 계정발급신청이 오면 관리자 전원에게
        # 알림. 관리 콘솔은 판독 콘솔 타입(analysis_done/share/chat)을
        # 제외한 나머지를 그대로 띄우므로 타입명이 달라져도 안전.
        ACCOUNT_REQUEST = "account_request", "계정 발급 요청"

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


class AccountRequest(models.Model):
    """계정발급신청 — 신규 의료진이 태블릿/React 웹(의료진용 클라이언트)에서
    신청을 제출하면 관리자(role=admin) 전원에게 알림이 가고, 관리 콘솔의
    요청 목록/승인/거절 API로 처리한다 (최일운 요청, 2026-08-05 — 기존엔
    Django 기본 admin 화면에서만 처리 가능했음). 환자용 모바일 앱과는
    무관 — Patient를 참조하지 않고 항상 User+Staff만 생성한다. 초대코드와
    달리 신청자가 스스로 비밀번호를 정하지 않는다 — 승인 시점에 서버가
    만든 임시 비밀번호를 승인 응답에서 1회만 반환하고, 관리자가 그걸
    복사해 신청자에게 직접(메일 등) 전달하는 방식이라 여기엔 비밀번호
    필드가 없다."""

    class Status(models.TextChoices):
        PENDING = "pending", "대기중"
        APPROVED = "approved", "승인됨"
        REJECTED = "rejected", "거절됨"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=50)
    email = models.EmailField()
    role = models.CharField(max_length=20)  # apps.staff.Staff.Role 값 중 하나
    department = models.CharField(max_length=100, blank=True)
    note = models.TextField(blank=True)
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING
    )
    reviewed_by = models.ForeignKey(
        "staff.Staff",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="+",
    )
    created_user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="account_request",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "account_request"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.name} ({self.status})"


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
