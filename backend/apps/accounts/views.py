from datetime import timedelta

from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import get_staff_or_403
from apps.staff.models import Staff

from .models import Invitation, User
from .serializers import (
    InvitationIssueSerializer,
    InvitationRedeemSerializer,
    InvitationSerializer,
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
