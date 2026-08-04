from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import get_staff_or_403

from .models import Staff
from .serializers import StaffMeUpdateSerializer, StaffSerializer


class StaffMeView(APIView):
    """설계문서 7.4절 — GET/PATCH /staff/me. 3.2-a."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=StaffSerializer)
    def get(self, request):
        staff = get_staff_or_403(request.user)
        return Response(StaffSerializer(staff).data)

    @extend_schema(request=StaffMeUpdateSerializer, responses=StaffSerializer)
    def patch(self, request):
        staff = get_staff_or_403(request.user)
        serializer = StaffMeUpdateSerializer(staff, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(StaffSerializer(staff).data)


class StaffListView(APIView):
    """설계문서 7.4절 — GET /staff. 채팅 상대·공유 대상 선택용."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=StaffSerializer(many=True))
    def get(self, request):
        get_staff_or_403(request.user)
        staff = Staff.objects.filter(
            employment_status=Staff.EmploymentStatus.ACTIVE
        ).order_by("department", "role")
        return Response(StaffSerializer(staff, many=True).data)


class StaffDeactivateView(APIView):
    """설계문서 7.4절 — DELETE /staff/{id}. 관리자 권한만."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=None, responses=StaffSerializer)
    def delete(self, request, staff_id):
        requester = get_staff_or_403(request.user)
        if requester.role != Staff.Role.ADMIN:
            raise PermissionDenied("관리자 권한 의료진만 직원을 비활성화할 수 있습니다.")

        target = get_object_or_404(Staff, id=staff_id)
        target.employment_status = Staff.EmploymentStatus.RESIGNED
        target.resigned_at = timezone.now().date()
        target.save(update_fields=["employment_status", "resigned_at", "updated_at"])

        target.user.is_active = False
        target.user.save(update_fields=["is_active"])

        return Response(StaffSerializer(target).data)
