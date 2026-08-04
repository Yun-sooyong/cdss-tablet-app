from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import get_patient_or_404

from .models import Reservation, ReservationHistory, Visit
from .serializers import (
    ReservationCreateSerializer,
    ReservationRescheduleSerializer,
    ReservationSerializer,
    VisitSerializer,
)


class PatientReservationListCreateView(APIView):
    """설계문서 7.3절 — GET /patients/me/reservations. 3.1-b.

    POST는 설계문서 API 표에는 없지만(예약 신청 경로가 없으면 예약을
    아무도 못 만든다는 설계 공백), 예약 요청 흐름상 필요해서 추가했다.
    """

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=ReservationSerializer(many=True))
    def get(self, request):
        patient = get_patient_or_404(request.user)
        qs = Reservation.objects.filter(patient=patient).order_by("scheduled_at")

        status_param = request.query_params.get("status")
        if status_param:
            qs = qs.filter(status=status_param)

        from_param = request.query_params.get("from")
        if from_param:
            qs = qs.filter(scheduled_at__gte=from_param)

        return Response(ReservationSerializer(qs, many=True).data)

    @extend_schema(request=ReservationCreateSerializer, responses=ReservationSerializer)
    def post(self, request):
        patient = get_patient_or_404(request.user)
        serializer = ReservationCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        reservation = Reservation.objects.create(
            patient=patient,
            department=serializer.validated_data["department"],
            scheduled_at=serializer.validated_data["scheduled_at"],
            status=Reservation.Status.REQUESTED,
        )
        return Response(
            ReservationSerializer(reservation).data, status=status.HTTP_201_CREATED
        )


class ReservationDetailView(APIView):
    """설계문서 7.3절 — 예약 상세/변경/취소. 본인 예약만 접근 가능."""

    permission_classes = [permissions.IsAuthenticated]

    def _get_reservation(self, request, reservation_id):
        patient = get_patient_or_404(request.user)
        return get_object_or_404(Reservation, id=reservation_id, patient=patient)

    @extend_schema(responses=ReservationSerializer)
    def get(self, request, reservation_id):
        reservation = self._get_reservation(request, reservation_id)
        return Response(ReservationSerializer(reservation).data)

    @extend_schema(
        request=ReservationRescheduleSerializer, responses=ReservationSerializer
    )
    def patch(self, request, reservation_id):
        """예약일 변경 — reservation_history 자동 기록."""
        reservation = self._get_reservation(request, reservation_id)
        serializer = ReservationRescheduleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        prev_scheduled_at = reservation.scheduled_at
        new_scheduled_at = serializer.validated_data["scheduled_at"]

        ReservationHistory.objects.create(
            reservation=reservation,
            prev_scheduled_at=prev_scheduled_at,
            new_scheduled_at=new_scheduled_at,
            changed_by=request.user,
        )

        reservation.scheduled_at = new_scheduled_at
        reservation.status = Reservation.Status.CHANGED
        reservation.change_reason = serializer.validated_data.get("change_reason", "")
        reservation.save(
            update_fields=["scheduled_at", "status", "change_reason", "updated_at"]
        )
        return Response(ReservationSerializer(reservation).data)

    @extend_schema(request=None, responses=ReservationSerializer)
    def delete(self, request, reservation_id):
        """예약 취소 — 물리 삭제가 아니라 status=CANCELED로 처리."""
        reservation = self._get_reservation(request, reservation_id)
        reservation.status = Reservation.Status.CANCELED
        reservation.save(update_fields=["status", "updated_at"])
        return Response(ReservationSerializer(reservation).data)


class PatientVisitListView(APIView):
    """설계문서 7.3절 — GET /patients/me/visits. 진단명 포함."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=VisitSerializer(many=True))
    def get(self, request):
        patient = get_patient_or_404(request.user)
        qs = (
            Visit.objects.filter(patient=patient, deleted_at__isnull=True)
            .prefetch_related("diagnoses__disease")
            .order_by("-visited_at")
        )
        return Response(VisitSerializer(qs, many=True).data)


class VisitDetailView(APIView):
    """설계문서 7.3절 — GET /visits/{id}. 본인 진료만 접근 가능."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=VisitSerializer)
    def get(self, request, visit_id):
        patient = get_patient_or_404(request.user)
        visit = get_object_or_404(
            Visit.objects.prefetch_related("diagnoses__disease"),
            id=visit_id,
            patient=patient,
            deleted_at__isnull=True,
        )
        return Response(VisitSerializer(visit).data)
