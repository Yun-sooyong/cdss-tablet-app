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


class StaffAdminUpdateSerializer(serializers.ModelSerializer):
    """관리자가 다른 직원 정보를 수정 (최일운 요청, 2026-08-05). role까지
    바꿀 수 있는 건 호출자가 관리자로 검증된 뒤라서 자기 자신을 못 바꾸는
    StaffMeUpdateSerializer보다 범위를 넓혔다. employment_status/resigned_at은
    여기서 안 다룬다 — DELETE /staff/{id}(비활성화 전용 흐름)가 이미 있다."""

    class Meta:
        model = Staff
        fields = ["role", "department"]
