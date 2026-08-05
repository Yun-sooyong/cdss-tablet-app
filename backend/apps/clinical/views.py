from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import get_patient_or_404, get_staff_or_403
from apps.staff.models import Staff

from .models import (
    DoseLog,
    DoseSchedule,
    Prescription,
    PrescriptionDrug,
    Reservation,
    ReservationHistory,
    Visit,
)
from .serializers import (
    DoseLogSerializer,
    DrugSerializer,
    MedicationLogCreateSerializer,
    PrescriptionSerializer,
    ReservationConfirmSerializer,
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
            reason=serializer.validated_data.get("reason", ""),
            document_type=serializer.validated_data.get(
                "document_type", Reservation.DocumentType.NONE
            ),
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


class StaffReservationListView(APIView):
    """GET /reservations/ — 의료진용 예약 목록 (정다희, 2026-08-05 —
    "CONFIRMED 하는 API도 있어야지" 요청으로 예약 확정 API와 같이 추가.
    이게 없으면 확정할 예약 자체를 찾을 방법이 없었음).

    ?status=, ?department= 필터 지원. 담당 배정 전(REQUESTED)이라
    특정 의료진 소유 개념이 없어서, 활성 직원이면 전체 조회 가능하게
    했다 — 접수 담당이 누구든 볼 수 있어야 하는 화면이라고 판단."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=ReservationSerializer(many=True))
    def get(self, request):
        get_staff_or_403(request.user)

        qs = Reservation.objects.select_related("patient", "department").order_by(
            "scheduled_at"
        )

        status_param = request.query_params.get("status")
        if status_param:
            qs = qs.filter(status=status_param)

        department_param = request.query_params.get("department")
        if department_param:
            qs = qs.filter(department_id=department_param)

        return Response(ReservationSerializer(qs, many=True).data)


class ReservationConfirmView(APIView):
    """POST /reservations/{id}/confirm/ — 예약 확정 + 담당 의료진 배정.

    staff_id를 안 주면 호출한 의료진 본인이 담당으로 배정된다. 확정되는
    순간 apps/clinical/signals.py가 환자한테 푸시 알림을 보낸다."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=ReservationConfirmSerializer, responses=ReservationSerializer)
    def post(self, request, reservation_id):
        requester = get_staff_or_403(request.user)
        reservation = get_object_or_404(Reservation, id=reservation_id)

        serializer = ReservationConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        staff_id = serializer.validated_data.get("staff_id")

        assigned_staff = requester
        if staff_id and staff_id != requester.id:
            assigned_staff = get_object_or_404(Staff, id=staff_id)

        if reservation.status == Reservation.Status.CANCELED:
            raise ValidationError("취소된 예약은 확정할 수 없습니다.")

        reservation.status = Reservation.Status.CONFIRMED
        reservation.staff = assigned_staff
        reservation.save(update_fields=["status", "staff", "updated_at"])

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


class PatientPrescriptionListView(APIView):
    """설계문서 7.3절 — GET /patients/me/prescriptions. 3.1-c."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=PrescriptionSerializer(many=True))
    def get(self, request):
        patient = get_patient_or_404(request.user)
        qs = (
            Prescription.objects.filter(visit__patient=patient)
            .prefetch_related("drugs__drug")
            .order_by("-prescribed_at")
        )
        return Response(PrescriptionSerializer(qs, many=True).data)


class PrescriptionDetailView(APIView):
    """설계문서 7.3절 — GET /prescriptions/{id}. 처방전 상세 + 파일 서명 URL."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=PrescriptionSerializer)
    def get(self, request, prescription_id):
        patient = get_patient_or_404(request.user)
        prescription = get_object_or_404(
            Prescription.objects.prefetch_related("drugs__drug"),
            id=prescription_id,
            visit__patient=patient,
        )
        return Response(PrescriptionSerializer(prescription).data)


class PatientMedicationScheduleView(APIView):
    """설계문서 7.3절 — GET /patients/me/medications/schedule. 3.1-d, 3.1-e.

    복약 캘린더(스케줄 목록) + 처방약 단위 잔량 %.
    잔량 % = (처방 총량 - 복용 기록) / 처방 총량 (설계문서 6.6절).
    """

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=None)
    def get(self, request):
        patient = get_patient_or_404(request.user)
        prescription_drugs = PrescriptionDrug.objects.filter(
            prescription__visit__patient=patient
        ).select_related("drug")

        from_param = request.query_params.get("from")
        to_param = request.query_params.get("to")

        result = []
        for pd in prescription_drugs:
            all_schedules = pd.schedules.all()
            total = all_schedules.count()
            taken = DoseLog.objects.filter(
                schedule__prescription_drug=pd, is_taken=True
            ).count()
            remaining_percent = (
                round((1 - taken / total) * 100, 1) if total else None
            )

            visible_schedules = all_schedules
            if from_param:
                visible_schedules = visible_schedules.filter(
                    scheduled_at__gte=from_param
                )
            if to_param:
                visible_schedules = visible_schedules.filter(
                    scheduled_at__lte=to_param
                )
            visible_schedules = visible_schedules.select_related("log")

            result.append(
                {
                    "prescription_drug_id": str(pd.id),
                    "drug": DrugSerializer(pd.drug).data,
                    "remaining_percent": remaining_percent,
                    "schedules": [
                        {
                            "id": str(s.id),
                            "scheduled_at": s.scheduled_at,
                            "is_taken": hasattr(s, "log") and s.log.is_taken,
                            "taken_at": (
                                s.log.taken_at if hasattr(s, "log") else None
                            ),
                        }
                        for s in visible_schedules
                    ],
                }
            )
        return Response(result)


class MedicationLogCreateView(APIView):
    """설계문서 7.3절 — POST /medications/logs. 복용 체크(dose_log 생성)."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=MedicationLogCreateSerializer, responses=DoseLogSerializer)
    def post(self, request):
        patient = get_patient_or_404(request.user)
        serializer = MedicationLogCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        schedule = get_object_or_404(
            DoseSchedule,
            id=serializer.validated_data["schedule_id"],
            prescription_drug__prescription__visit__patient=patient,
        )
        log, _ = DoseLog.objects.update_or_create(
            schedule=schedule,
            defaults={"is_taken": True, "taken_at": timezone.now()},
        )
        return Response(DoseLogSerializer(log).data, status=status.HTTP_201_CREATED)
