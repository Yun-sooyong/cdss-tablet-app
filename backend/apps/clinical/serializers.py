from rest_framework import serializers

from apps.staff.models import Department

from .models import Diagnosis, Disease, Reservation, Visit


class ReservationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Reservation
        fields = [
            "id",
            "patient",
            "staff",
            "department",
            "scheduled_at",
            "status",
            "change_reason",
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


class ReservationCreateSerializer(serializers.Serializer):
    department = serializers.PrimaryKeyRelatedField(queryset=Department.objects.all())
    scheduled_at = serializers.DateTimeField()


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
            "visited_at",
            "note",
            "diagnoses",
            "created_at",
        ]
        read_only_fields = fields
