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
    Invitation,
    Notification,
    QRToken,
    User,
)
from .serializers import (
    AccountRequestCreateSerializer,
    AuditLogSerializer,
    DeviceTokenSerializer,
    InvitationIssueSerializer,
    InvitationRedeemSerializer,
    InvitationSerializer,
    LogoutSerializer,
    NotificationSerializer,
    PasswordChangeSerializer,
    QRTokenSerializer,
    QRVerifySerializer,
)


class InvitationIssueView(APIView):
    """초대코드 발급/조회 — 관리자 권한 의료진만 (설계문서 7장/12장).

    조회(GET)는 원래 없어서 새로고침하면 발급 내역이 사라지는 문제가
    있었다 (최일운 요청, 2026-08-05). 관리자 콘솔 화면이라 issued_by
    본인 것만이 아니라 전체를 보여준다 — 다른 관리자가 발급한 코드도
    관리자라면 봐야 초대 현황을 파악할 수 있다고 판단했다. 이 범위가
    맞는지는 확인 필요."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=InvitationSerializer(many=True))
    def get(self, request):
        staff = get_staff_or_403(request.user)
        if staff.role != Staff.Role.ADMIN:
            raise PermissionDenied("관리자 권한 의료진만 초대코드 목록을 볼 수 있습니다.")

        invitations = Invitation.objects.order_by("-created_at")
        return Response(InvitationSerializer(invitations, many=True).data)

    @extend_schema(request=InvitationIssueSerializer, responses=InvitationSerializer)
    def post(self, request):
        staff = get_staff_or_403(request.user)
        if staff.role != Staff.Role.ADMIN:
            raise PermissionDenied("관리자 권한 의료진만 초대코드를 발급할 수 있습니다.")

        serializer = InvitationIssueSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        invitation = Invitation.objects.create(
            issued_by=staff,
            role=data["role"],
            department=data["department"],
            expires_at=timezone.now() + timedelta(days=data["expires_in_days"]),
        )
        return Response(
            InvitationSerializer(invitation).data, status=status.HTTP_201_CREATED
        )


class AccountRequestCreateView(APIView):
    """POST /auth/account-requests/ — 계정발급신청. 로그인 불필요.

    신청자가 스스로 아이디/비밀번호를 정하지 않는다 — 여기선 이름/이메일/
    희망 role·부서만 받아서 AccountRequest(대기중)를 만든다. 승인은
    Django 기본 admin 화면(/admin/)에서 관리자가 직접 처리한다
    (apps/accounts/admin.py `AccountRequestAdmin`의 승인 액션 참고) —
    앱 안의 Staff(role=admin) 유저가 아니라 개발/인사팀이 관리자실
    운영자로 이 화면을 쓴다는 전제라 별도 알림(FCM 등) 발송은 없다."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    @extend_schema(request=AccountRequestCreateSerializer, responses=None)
    def post(self, request):
        serializer = AccountRequestCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        AccountRequest.objects.create(**serializer.validated_data)
        return Response(status=status.HTTP_201_CREATED)


class InvitationRedeemView(APIView):
    """초대코드로 의료진 가입 — 로그인 불필요."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    @extend_schema(request=InvitationRedeemSerializer, responses=None)
    def post(self, request):
        serializer = InvitationRedeemSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        invitation = get_object_or_404(Invitation, code=data["code"])
        if not invitation.is_valid():
            raise ValidationError("만료되었거나 이미 사용된 초대코드입니다.")

        if User.objects.filter(username=data["username"]).exists():
            raise ValidationError("이미 사용 중인 아이디입니다.")

        user = User.objects.create_user(
            username=data["username"],
            email=data["email"],
            password=data["password"],
        )
        Staff.objects.create(
            user=user, role=invitation.role, department=invitation.department
        )
        invitation.is_used = True
        invitation.used_by = user
        invitation.save(update_fields=["is_used", "used_by"])

        return Response(status=status.HTTP_201_CREATED)


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
    """설계문서 7.4절 — POST /qr/verify. 태블릿 전용, 의료진 인증 필요."""

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

        from apps.patients.serializers import PatientSerializer

        return Response(PatientSerializer(qr.patient).data)


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
