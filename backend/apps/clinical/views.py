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
    Diagnosis,
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
    PrescriptionCreateSerializer,
    PrescriptionSerializer,
    ReservationConfirmSerializer,
    ReservationCreateSerializer,
    ReservationRescheduleSerializer,
    ReservationSerializer,
    VisitCreateSerializer,
    VisitSerializer,
)
from .services import generate_dose_schedules


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


class StaffVisitCreateView(APIView):
    """POST /visits/ — 의료진용 진료기록 생성.

    지금까지 Visit/Prescription을 만드는 API가 없어서 전부 스크립트로
    직접 넣어왔다 — 그 공백을 메우는 첫 엔드포인트. diagnoses를 같이
    받아서 한 번의 요청으로 진단까지 붙인다(Diagnosis 단독 생성 API는
    없음, 진료 기록 시점에 항상 같이 만들어지는 데이터라서)."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=VisitCreateSerializer, responses=VisitSerializer)
    def post(self, request):
        staff = get_staff_or_403(request.user)
        serializer = VisitCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        visit = Visit.objects.create(
            patient=data["patient"],
            staff=staff,
            department=data["department"],
            visited_at=data["visited_at"],
            note=data["note"],
        )
        Diagnosis.objects.bulk_create(
            [
                Diagnosis(
                    visit=visit,
                    disease=d["disease"],
                    is_primary=d["is_primary"],
                )
                for d in data["diagnoses"]
            ]
        )

        visit = Visit.objects.prefetch_related("diagnoses__disease").get(id=visit.id)
        return Response(VisitSerializer(visit).data, status=status.HTTP_201_CREATED)


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


class StaffPrescriptionCreateView(APIView):
    """POST /prescriptions/ — 의료진용 처방 생성.

    drugs 항목마다 PrescriptionDrug를 만들고, 그때마다
    generate_dose_schedules()로 dose_schedule을 같이 생성한다 — 이게
    없으면 처방은 생기는데 환자 앱 복약 캘린더엔 아무것도 안 뜬다.
    처방전 파일 업로드는 범위 밖(필요해지면 batch 이미지 업로드와 같은
    서명 URL 패턴으로 추가)."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=PrescriptionCreateSerializer, responses=PrescriptionSerializer)
    def post(self, request):
        staff = get_staff_or_403(request.user)
        serializer = PrescriptionCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        prescription = Prescription.objects.create(
            visit=data["visit"],
            staff=staff,
            prescribed_at=data["prescribed_at"],
        )
        for drug_data in data["drugs"]:
            prescription_drug = PrescriptionDrug.objects.create(
                prescription=prescription,
                drug=drug_data["drug"],
                dose_per_take=drug_data["dose_per_take"],
                times_per_day=drug_data["times_per_day"],
                total_days=drug_data["total_days"],
            )
            generate_dose_schedules(prescription_drug, data["prescribed_at"])

        prescription = Prescription.objects.prefetch_related("drugs__drug").get(
            id=prescription.id
        )
        return Response(
            PrescriptionSerializer(prescription).data, status=status.HTTP_201_CREATED
        )


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


class MedicationLogDeleteView(APIView):
    """DELETE /medications/logs/{schedule_id}/ — 복용 체크 취소.

    DoseLog는 BaseModel이 아니라 deleted_at도 없는 단순 체크 상태라(
    진료기록 본체가 아니라 "먹었다/안먹었다" 토글) soft delete 규칙
    대상이 아니다. row 자체를 지운다. schedule_id를 키로 받는 이유는
    POST /medications/logs가 이미 schedule_id로 받고 있어서 대칭을
    맞춘 것 — 프론트가 log의 id를 별도로 들고 있을 필요가 없다.
    """

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=None, responses=None)
    def delete(self, request, schedule_id):
        patient = get_patient_or_404(request.user)
        schedule = get_object_or_404(
            DoseSchedule,
            id=schedule_id,
            prescription_drug__prescription__visit__patient=patient,
        )
        DoseLog.objects.filter(schedule=schedule).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
