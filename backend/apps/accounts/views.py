from datetime import timedelta

from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.audit import log_access
from apps.common.permissions import get_patient_or_404, get_staff_or_403
from apps.staff.models import Staff

from .models import AuditLog, DeviceToken, Invitation, Notification, QRToken, User
from .serializers import (
    DeviceTokenSerializer,
    InvitationIssueSerializer,
    InvitationRedeemSerializer,
    InvitationSerializer,
    NotificationSerializer,
    QRTokenSerializer,
    QRVerifySerializer,
)


class InvitationIssueView(APIView):
    """초대코드 발급 — 관리자 권한 의료진만 (설계문서 7장/12장)."""

    permission_classes = [permissions.IsAuthenticated]

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
