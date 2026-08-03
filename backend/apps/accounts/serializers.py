from rest_framework import serializers

from apps.staff.models import Staff

from .models import Invitation


class InvitationIssueSerializer(serializers.Serializer):
    role = serializers.ChoiceField(choices=Staff.Role.choices)
    department = serializers.CharField(
        max_length=100, required=False, allow_blank=True, default=""
    )
    expires_in_days = serializers.IntegerField(
        required=False, default=7, min_value=1, max_value=30
    )


class InvitationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Invitation
        fields = ["code", "role", "department", "expires_at", "is_used", "created_at"]
        read_only_fields = fields


class InvitationRedeemSerializer(serializers.Serializer):
    code = serializers.CharField(max_length=12)
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=8)
