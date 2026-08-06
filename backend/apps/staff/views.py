from datetime import datetime, time, timedelta

from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import get_staff_or_403

from .models import Department, Staff
from .serializers import (
    DepartmentSerializer,
    StaffAdminUpdateSerializer,
    StaffMeUpdateSerializer,
    StaffSerializer,
)

# 부서별 운영시간 테이블이 아직 없어서(설계문서에도 스키마에도 없음) 상수로
# 고정 — 09:00~18:00, 30분 간격, 점심 12~13시 제외 (정다희, 2026-08-05).
# 필요해지면 부서별 운영시간 테이블로 승격.
_SLOT_DURATION_MINUTES = 30
_SLOT_RANGES = [(time(9, 0), time(12, 0)), (time(13, 0), time(18, 0))]


def _generate_slot_times() -> list[time]:
    slots = []
    anchor = datetime(2000, 1, 1)
    for start, end in _SLOT_RANGES:
        cursor = datetime.combine(anchor, start)
        range_end = datetime.combine(anchor, end)
        while cursor < range_end:
            slots.append(cursor.time())
            cursor += timedelta(minutes=_SLOT_DURATION_MINUTES)
    return slots


_AVAILABLE_SLOT_TIMES = _generate_slot_times()


class DepartmentListView(APIView):
    """설계문서 6.4절 — 부서 코드 목록. 예약 신청 드롭다운 등에서 사용
    (서정은 요청, 2026-08-04)."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=DepartmentSerializer(many=True))
    def get(self, request):
        departments = Department.objects.order_by("name")
        return Response(DepartmentSerializer(departments, many=True).data)


class DepartmentAvailableSlotsView(APIView):
    """GET /departments/{dept_code}/available-slots/?date=YYYY-MM-DD.

    날짜별 예약 가능 시간 조회 (정다희, 2026-08-05). 09:00~18:00,
    30분 간격, 점심 12~13시 제외 슬롯 중 이미 예약(REQUESTED/CONFIRMED/
    CHANGED)이 찬 시간을 available=false로 표시한다.
    """

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=None)
    def get(self, request, dept_code):
        from apps.clinical.models import Reservation  # noqa: PLC0415 — 순환 임포트 회피

        department = get_object_or_404(Department, dept_code=dept_code)

        date_param = request.query_params.get("date")
        if not date_param:
            raise ValidationError("date 쿼리 파라미터가 필요합니다 (YYYY-MM-DD).")
        try:
            target_date = datetime.strptime(date_param, "%Y-%m-%d").date()
        except ValueError:
            raise ValidationError("date 형식이 올바르지 않습니다 (YYYY-MM-DD).")

        day_start = timezone.make_aware(datetime.combine(target_date, time.min))
        day_end = timezone.make_aware(datetime.combine(target_date, time.max))

        booked_at = Reservation.objects.filter(
            department=department,
            scheduled_at__range=(day_start, day_end),
            status__in=[
                Reservation.Status.REQUESTED,
                Reservation.Status.CONFIRMED,
                Reservation.Status.CHANGED,
            ],
        ).values_list("scheduled_at", flat=True)
        booked_times = {timezone.localtime(dt).time() for dt in booked_at}

        result = [
            {
                "time": slot.strftime("%H:%M"),
                "available": slot not in booked_times,
            }
            for slot in _AVAILABLE_SLOT_TIMES
        ]
        return Response(result)


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


class StaffDetailView(APIView):
    """설계문서 7.4절 — PATCH/DELETE /staff/{id}. 둘 다 관리자 권한만.

    PATCH는 role/department 수정(최일운 요청, 2026-08-05) — 예: 신규
    입사자를 doctor에서 admin으로 승격. DELETE는 비활성화(기존)."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=StaffAdminUpdateSerializer, responses=StaffSerializer)
    def patch(self, request, staff_id):
        requester = get_staff_or_403(request.user)
        if requester.role != Staff.Role.ADMIN:
            raise PermissionDenied("관리자 권한 의료진만 다른 직원 정보를 수정할 수 있습니다.")

        target = get_object_or_404(Staff, id=staff_id)
        serializer = StaffAdminUpdateSerializer(target, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(StaffSerializer(target).data)

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
