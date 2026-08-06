from rest_framework import serializers

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
