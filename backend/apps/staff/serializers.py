from rest_framework import serializers

from .models import Department, Staff


class DepartmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Department
        fields = ["dept_code", "name", "extension"]
        read_only_fields = fields


class StaffSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username", read_only=True)
    email = serializers.EmailField(source="user.email", read_only=True)

    class Meta:
        model = Staff
        fields = [
            "id",
            "username",
            "email",
            "role",
            "department",
            "employment_status",
            "resigned_at",
            "created_at",
        ]
        read_only_fields = fields


class StaffMeUpdateSerializer(serializers.ModelSerializer):
    """본인 정보 수정 — role은 권한 상승 위험이 있어 본인이 못 바꾸게 department만 허용."""

    class Meta:
        model = Staff
        fields = ["department"]
