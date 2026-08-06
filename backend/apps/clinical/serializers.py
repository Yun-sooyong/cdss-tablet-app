from rest_framework import serializers

from apps.patients.models import Patient
from apps.patients.serializers import PatientSummarySerializer
from apps.staff.models import Department

from .models import Diagnosis, Disease, DoseLog, Drug, Prescription, PrescriptionDrug, Reservation, Visit
from .services import build_file_url


class ReservationSerializer(serializers.ModelSerializer):
    # 의료진용 목록/확정 화면에서 환자 맥락 필요 — 최일운 batch/job
    # patient_summary와 같은 패턴 (정다희, 2026-08-05).
    patient_summary = PatientSummarySerializer(source="patient", read_only=True)

    class Meta:
        model = Reservation
        fields = [
            "id",
            "patient",
            "patient_summary",
            "staff",
            "department",
            "scheduled_at",
            "status",
            "change_reason",
            "reason",
            "document_type",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "patient",
            "staff",
            "status",
            "created_at",
            "updated_at",
        ]


class ReservationConfirmSerializer(serializers.Serializer):
    staff_id = serializers.UUIDField(required=False)


class ReservationCreateSerializer(serializers.Serializer):
    department = serializers.PrimaryKeyRelatedField(queryset=Department.objects.all())
    scheduled_at = serializers.DateTimeField()
    reason = serializers.CharField(
        max_length=500, required=False, allow_blank=True, default=""
    )
    document_type = serializers.ChoiceField(
        choices=Reservation.DocumentType.choices,
        required=False,
        default=Reservation.DocumentType.NONE,
    )


class ReservationRescheduleSerializer(serializers.Serializer):
    scheduled_at = serializers.DateTimeField()
    change_reason = serializers.CharField(
        max_length=200, required=False, allow_blank=True, default=""
    )


class DiseaseSerializer(serializers.ModelSerializer):
    class Meta:
        model = Disease
        fields = ["code", "name_ko", "name_en"]
        read_only_fields = fields


class DiagnosisSerializer(serializers.ModelSerializer):
    disease = DiseaseSerializer(read_only=True)

    class Meta:
        model = Diagnosis
        fields = ["id", "disease", "is_primary"]
        read_only_fields = fields


class DiagnosisCreateSerializer(serializers.Serializer):
    disease = serializers.PrimaryKeyRelatedField(queryset=Disease.objects.all())
    is_primary = serializers.BooleanField(required=False, default=False)


class VisitCreateSerializer(serializers.Serializer):
    """POST /visits/ — 의료진용 진료기록 생성. 예약 없이도 접수 가능하다는
    기존 Visit 설계(reservation FK 없음)를 그대로 따른다 — 예약 연동은
    필요해지면 별도로 추가."""

    patient = serializers.PrimaryKeyRelatedField(
        queryset=Patient.objects.filter(deleted_at__isnull=True)
    )
    department = serializers.PrimaryKeyRelatedField(
        queryset=Department.objects.all(), required=False, allow_null=True, default=None
    )
    visited_at = serializers.DateTimeField(required=False)
    note = serializers.CharField(required=False, allow_blank=True, default="")
    diagnoses = DiagnosisCreateSerializer(many=True, required=False, default=list)

    def validate(self, attrs):
        if not attrs.get("visited_at"):
            from django.utils import timezone

            attrs["visited_at"] = timezone.now()
        return attrs


class VisitSerializer(serializers.ModelSerializer):
    diagnoses = DiagnosisSerializer(many=True, read_only=True)

    class Meta:
        model = Visit
        fields = [
            "id",
            "patient",
            "staff",
            "department",
            "visited_at",
            "note",
            "diagnoses",
            "created_at",
        ]
        read_only_fields = fields


class DrugSerializer(serializers.ModelSerializer):
    class Meta:
        model = Drug
        fields = ["code", "product_name", "ingredient", "unit"]
        read_only_fields = fields


class PrescriptionDrugSerializer(serializers.ModelSerializer):
    drug = DrugSerializer(read_only=True)

    class Meta:
        model = PrescriptionDrug
        fields = ["id", "drug", "dose_per_take", "times_per_day", "total_days"]
        read_only_fields = fields


class PrescriptionDrugCreateSerializer(serializers.Serializer):
    drug = serializers.PrimaryKeyRelatedField(queryset=Drug.objects.all())
    dose_per_take = serializers.DecimalField(max_digits=6, decimal_places=2)
    times_per_day = serializers.IntegerField(min_value=1)
    total_days = serializers.IntegerField(min_value=1)


class PrescriptionCreateSerializer(serializers.Serializer):
    """POST /prescriptions/ — 의료진용 처방 생성. drugs 항목마다
    PrescriptionDrug를 만들고, times_per_day/total_days 기준으로
    dose_schedule을 같이 생성한다 (apps/clinical/services.py
    generate_dose_schedules) — 이게 없으면 처방은 생겨도 환자 앱
    복약 캘린더/알림엔 아무것도 안 뜬다."""

    visit = serializers.PrimaryKeyRelatedField(
        queryset=Visit.objects.filter(deleted_at__isnull=True)
    )
    prescribed_at = serializers.DateField(required=False)
    drugs = PrescriptionDrugCreateSerializer(many=True)

    def validate_drugs(self, value):
        if not value:
            raise serializers.ValidationError("최소 1개 이상의 약을 포함해야 합니다.")
        return value

    def validate(self, attrs):
        if not attrs.get("prescribed_at"):
            from django.utils import timezone

            attrs["prescribed_at"] = timezone.localdate()
        return attrs


class PrescriptionSerializer(serializers.ModelSerializer):
    drugs = PrescriptionDrugSerializer(many=True, read_only=True)
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = Prescription
        fields = [
            "id",
            "visit",
            "staff",
            "prescribed_at",
            "file_url",
            "drugs",
            "created_at",
        ]
        read_only_fields = fields

    def get_file_url(self, obj) -> str | None:
        return build_file_url(obj.file_key) if obj.file_key else None


class MedicationLogCreateSerializer(serializers.Serializer):
    schedule_id = serializers.UUIDField()


class DoseLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = DoseLog
        fields = ["id", "schedule", "is_taken", "taken_at"]
        read_only_fields = fields
