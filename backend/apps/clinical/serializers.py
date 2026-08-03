from rest_framework import serializers

from apps.staff.models import Department

from .models import Reservation


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
