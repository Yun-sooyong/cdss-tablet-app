from rest_framework import serializers

from apps.staff.models import Staff

from .models import AccountRequest, AuditLog, DeviceToken, Notification, QRToken


class AccountRequestCreateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=50)
    email = serializers.EmailField()
    role = serializers.ChoiceField(choices=Staff.Role.choices)
    department = serializers.CharField(
        max_length=100, required=False, allow_blank=True, default=""
    )
    note = serializers.CharField(
        required=False, allow_blank=True, default=""
    )


class AccountRequestSerializer(serializers.ModelSerializer):
    reviewed_by_username = serializers.CharField(
        source="reviewed_by.user.username", read_only=True, default=None
    )

    class Meta:
        model = AccountRequest
        fields = [
            "id",
            "name",
            "email",
            "role",
            "department",
            "note",
            "status",
            "created_at",
            "reviewed_at",
            "reviewed_by",
            "reviewed_by_username",
            "created_user",
        ]
        read_only_fields = fields


class AccountRequestApproveSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    role = serializers.ChoiceField(choices=Staff.Role.choices)
    department = serializers.CharField(
        max_length=100, required=False, allow_blank=True, default=""
    )


class AccountRequestRejectSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, default="")


class QRTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = QRToken
        fields = ["token", "issued_at", "expires_at"]
        read_only_fields = fields


class QRVerifySerializer(serializers.Serializer):
    token = serializers.CharField(max_length=64)


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ["id", "fcm_token", "platform", "updated_at"]
        read_only_fields = ["id", "updated_at"]


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = [
            "id",
            "type",
            "body",
            "target_type",
            "target_id",
            "is_read",
            "created_at",
        ]
        read_only_fields = fields


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()


class PasswordChangeSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)


class AuditLogSerializer(serializers.ModelSerializer):
    actor_username = serializers.CharField(source="actor_user.username", read_only=True)

    class Meta:
        model = AuditLog
        fields = [
            "id",
            "actor_user",
            "actor_username",
            "action",
            "target_table",
            "target_id",
            "patient",
            "ip",
            "created_at",
        ]
        read_only_fields = fields
