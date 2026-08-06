import secrets
from datetime import timedelta

from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from apps.common.audit import log_access
from apps.common.permissions import get_patient_or_404, get_staff_or_403
from apps.staff.models import Staff

from .models import (
    AccountRequest,
    AuditLog,
    DeviceToken,
    Notification,
    QRToken,
    User,
)
from .serializers import (
    AccountRequestApproveSerializer,
    AccountRequestCreateSerializer,
    AccountRequestRejectSerializer,
    AccountRequestSerializer,
    AuditLogSerializer,
    DeviceTokenSerializer,
    LogoutSerializer,
    NotificationSerializer,
    PasswordChangeSerializer,
    QRTokenSerializer,
    QRVerifySerializer,
)
from .services import notify


def _require_admin(user):
    staff = get_staff_or_403(user)
    if staff.role != Staff.Role.ADMIN:
        raise PermissionDenied("관리자 권한 의료진만 이용할 수 있습니다.")
    return staff


class AccountRequestListCreateView(APIView):
    """계정발급신청 목록/생성.

    POST(로그인 불필요) — 신청자가 스스로 아이디/비밀번호를 정하지
    않는다. 이름/이메일/희망 role·부서·사유만 받아서 AccountRequest
    (대기중)를 만들고, role=admin인 Staff 전원에게 알림을 보낸다.
    같은 이메일로 대기중인 신청이 이미 있으면 중복 신청을 막는다.

    GET(관리자 전용) — 관리 콘솔의 요청 목록 화면. ?status=로 필터
    (최일운 요청, 2026-08-05 — 기존엔 Django 기본 admin 화면에서만
    조회/처리가 가능했음. apps/accounts/admin.py 참고)."""

    permission_classes = [permissions.AllowAny]

    def get_permissions(self):
        if self.request.method == "GET":
            return [permissions.IsAuthenticated()]
        return [permissions.AllowAny()]

    @extend_schema(responses=AccountRequestSerializer(many=True))
    def get(self, request):
        _require_admin(request.user)

        requests_qs = AccountRequest.objects.order_by("-created_at")
        status_filter = request.query_params.get("status")
        if status_filter:
            requests_qs = requests_qs.filter(status=status_filter.lower())

        return Response(AccountRequestSerializer(requests_qs, many=True).data)

    @extend_schema(request=AccountRequestCreateSerializer, responses=None)
    def post(self, request):
        serializer = AccountRequestCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        if AccountRequest.objects.filter(
            email=data["email"], status=AccountRequest.Status.PENDING
        ).exists():
            raise ValidationError("이미 대기중인 신청이 있습니다.")

        account_request = AccountRequest.objects.create(**data)

        for admin_staff in Staff.objects.filter(role=Staff.Role.ADMIN):
            notify(
                admin_staff.user,
                Notification.Type.ACCOUNT_REQUEST,
                body=f"{account_request.name}님이 계정 발급을 요청했습니다.",
                target_type="account_request",
                target_id=account_request.id,
            )

        return Response(
            {"id": account_request.id, "status": account_request.status},
            status=status.HTTP_201_CREATED,
        )


class AccountRequestApproveView(APIView):
    """POST /auth/account-requests/{id}/approve/ — 관리자 전용.

    User+Staff를 생성하고, 서버가 만든 임시 비밀번호를 이 응답에서만
    평문으로 반환한다 — 다시 조회할 수 없으므로 관리자가 바로 복사해
    신청자에게 전달해야 한다."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=AccountRequestApproveSerializer, responses=None)
    def post(self, request, request_id):
        staff = _require_admin(request.user)

        account_request = get_object_or_404(AccountRequest, id=request_id)
        if account_request.status != AccountRequest.Status.PENDING:
            raise ValidationError("이미 처리된 신청입니다.")

        serializer = AccountRequestApproveSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        if User.objects.filter(username=data["username"]).exists():
            raise ValidationError("이미 사용 중인 아이디입니다.")

        temporary_password = secrets.token_urlsafe(9)
        user = User.objects.create_user(
            username=data["username"],
            email=account_request.email,
            password=temporary_password,
        )
        Staff.objects.create(
            user=user, role=data["role"], department=data["department"]
        )

        account_request.status = AccountRequest.Status.APPROVED
        account_request.reviewed_by = staff
        account_request.reviewed_at = timezone.now()
        account_request.created_user = user
        account_request.save(
            update_fields=["status", "reviewed_by", "reviewed_at", "created_user"]
        )

        return Response(
            {"username": data["username"], "temporary_password": temporary_password}
        )


class AccountRequestRejectView(APIView):
    """POST /auth/account-requests/{id}/reject/ — 관리자 전용."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=AccountRequestRejectSerializer, responses=None)
    def post(self, request, request_id):
        staff = _require_admin(request.user)

        account_request = get_object_or_404(AccountRequest, id=request_id)
        if account_request.status != AccountRequest.Status.PENDING:
            raise ValidationError("이미 처리된 신청입니다.")

        serializer = AccountRequestRejectSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        account_request.status = AccountRequest.Status.REJECTED
        account_request.reviewed_by = staff
        account_request.reviewed_at = timezone.now()
        account_request.save(update_fields=["status", "reviewed_by", "reviewed_at"])

        return Response(status=status.HTTP_204_NO_CONTENT)


class PatientQRIssueView(APIView):
    """설계문서 7.3절/3.1-f — POST /patients/me/qr. 일회성·5분 만료."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=None, responses=QRTokenSerializer)
    def post(self, request):
        patient = get_patient_or_404(request.user)
        qr = QRToken.objects.create(
            patient=patient, expires_at=timezone.now() + timedelta(minutes=5)
        )
        return Response(QRTokenSerializer(qr).data, status=status.HTTP_201_CREATED)


class QRVerifyView(APIView):
    """설계문서 7.4절 — POST /qr/verify. 태블릿 전용, 의료진 인증 필요.

    QR 스캔 확인 화면 정보 보강 (수용님 요청, 2026-08-06) — 연락처는
    PatientSerializer에 이미 있었고, 추가로 최근 방문일/최근 방문
    주진단명/오늘 예약 목록(여러 건 가능)을 같이 내려준다.
    `Patient.last_visit_at`은 DB 컬럼은 있지만 실제로 채워주는 코드가
    없어 항상 비어있으므로 쓰지 않고, 그때그때 Visit에서 직접 조회한다."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=QRVerifySerializer, responses=None)
    def post(self, request):
        staff = get_staff_or_403(request.user)
        serializer = QRVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        qr = get_object_or_404(QRToken, token=serializer.validated_data["token"])
        if not qr.is_valid():
            raise ValidationError("만료되었거나 이미 사용된 QR코드입니다.")

        qr.is_used = True
        qr.verified_by = staff
        qr.save(update_fields=["is_used", "verified_by"])

        log_access(
            request,
            AuditLog.Action.READ,
            target_table="patient",
            target_id=qr.patient_id,
            patient=qr.patient,
        )

        from apps.clinical.models import Reservation, Visit  # noqa: PLC0415 — 순환 임포트 회피
        from apps.clinical.serializers import ReservationSerializer
        from apps.patients.serializers import PatientSerializer

        patient = qr.patient

        last_visit = (
            Visit.objects.filter(patient=patient, deleted_at__isnull=True)
            .prefetch_related("diagnoses__disease")
            .order_by("-visited_at")
            .first()
        )
        last_visit_diagnosis = None
        if last_visit:
            primary = next(
                (d for d in last_visit.diagnoses.all() if d.is_primary), None
            )
            if primary:
                last_visit_diagnosis = primary.disease.name_ko

        today_reservations = (
            Reservation.objects.filter(
                patient=patient, scheduled_at__date=timezone.localdate()
            )
            .exclude(status=Reservation.Status.CANCELED)
            .order_by("scheduled_at")
        )

        data = PatientSerializer(patient).data
        data["last_visit_at"] = last_visit.visited_at if last_visit else None
        data["last_visit_diagnosis"] = last_visit_diagnosis
        data["today_reservations"] = ReservationSerializer(
            today_reservations, many=True
        ).data

        return Response(data)


class DeviceTokenRegisterView(APIView):
    """설계문서 7.4절/9장 — POST /devices/tokens. FCM 토큰 등록."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=DeviceTokenSerializer, responses=DeviceTokenSerializer)
    def post(self, request):
        serializer = DeviceTokenSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        token, _ = DeviceToken.objects.update_or_create(
            user=request.user,
            fcm_token=serializer.validated_data["fcm_token"],
            defaults={"platform": serializer.validated_data["platform"]},
        )
        return Response(
            DeviceTokenSerializer(token).data, status=status.HTTP_201_CREATED
        )


class NotificationListView(APIView):
    """설계문서 7.4절/3.2-f — GET /notifications. 본인 알림만."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=NotificationSerializer(many=True))
    def get(self, request):
        notifications = Notification.objects.filter(user=request.user)
        return Response(NotificationSerializer(notifications, many=True).data)


class NotificationReadView(APIView):
    """PATCH /notifications/{id} — 읽음 처리. 본인 알림만 (최일운 요청,
    2026-08-05 — 지금까지 목록 조회만 있고 읽음 처리가 없었음)."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=None, responses=NotificationSerializer)
    def patch(self, request, notification_id):
        notification = get_object_or_404(
            Notification, id=notification_id, user=request.user
        )
        notification.is_read = True
        notification.save(update_fields=["is_read"])
        return Response(NotificationSerializer(notification).data)


class NotificationReadAllView(APIView):
    """POST /notifications/read-all — 본인의 안 읽은 알림 전체 읽음 처리."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=None, responses=None)
    def post(self, request):
        Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return Response(status=status.HTTP_204_NO_CONTENT)


class AuditLogListView(APIView):
    """GET /audit-logs — 접근 로그 조회 (최일운 요청, 2026-08-05).

    지금까지 기록(log_access)만 되고 조회 API가 없었다. 누가 어떤
    환자 정보를 봤는지가 드러나는 민감한 로그라 관리자 권한만 조회
    가능하게 했다 — 이 범위가 맞는지는 확인 필요(의료진 본인이 자기
    행위 로그만 보는 것도 허용할지 등). ?patient_id=로 특정 환자
    기준 조회, ?actor_user_id=로 특정 직원 기준 조회 지원.
    """

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=AuditLogSerializer(many=True))
    def get(self, request):
        staff = get_staff_or_403(request.user)
        if staff.role != Staff.Role.ADMIN:
            raise PermissionDenied("관리자 권한 의료진만 감사 로그를 조회할 수 있습니다.")

        logs = AuditLog.objects.select_related("actor_user").order_by("-created_at")

        patient_id = request.query_params.get("patient_id")
        if patient_id:
            logs = logs.filter(patient_id=patient_id)

        actor_user_id = request.query_params.get("actor_user_id")
        if actor_user_id:
            logs = logs.filter(actor_user_id=actor_user_id)

        return Response(AuditLogSerializer(logs[:200], many=True).data)


class LogoutView(APIView):
    """설계문서 7.2절 — POST /auth/logout. refresh 토큰 폐기(blacklist)."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=LogoutSerializer, responses=None)
    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            token = RefreshToken(serializer.validated_data["refresh"])
            token.blacklist()
        except TokenError as exc:
            raise ValidationError("유효하지 않은 refresh 토큰입니다.") from exc

        return Response(status=status.HTTP_205_RESET_CONTENT)


class PasswordChangeView(APIView):
    """POST /auth/password/change. 본인 비밀번호 변경 — 환자/의료진 공용
    (정은님 요청, 2026-08-04)."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=PasswordChangeSerializer, responses=None)
    def post(self, request):
        serializer = PasswordChangeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        if not request.user.check_password(data["old_password"]):
            raise ValidationError("현재 비밀번호가 일치하지 않습니다.")

        request.user.set_password(data["new_password"])
        request.user.save(update_fields=["password"])

        return Response(status=status.HTTP_204_NO_CONTENT)
