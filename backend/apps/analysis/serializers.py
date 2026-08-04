from rest_framework import serializers

from apps.patients.models import Patient
from apps.staff.models import Staff

from .models import AnalysisShare, Batch, Image, Job, ModelVersion


class ModelVersionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ModelVersion
        fields = ["id", "name", "version", "conformal_q", "is_active", "created_at"]
        read_only_fields = fields


class BatchSerializer(serializers.ModelSerializer):
    class Meta:
        model = Batch
        fields = ["id", "patient", "status", "created_by", "created_at", "updated_at"]
        read_only_fields = fields


class BatchCreateSerializer(serializers.Serializer):
    patient_id = serializers.PrimaryKeyRelatedField(
        source="patient", queryset=Patient.objects.all()
    )


class ImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Image
        fields = ["id", "batch", "storage_key", "original_filename", "created_at"]
        read_only_fields = fields


class ImageUploadRequestSerializer(serializers.Serializer):
    original_filename = serializers.CharField(max_length=255)


class ImageUploadResponseSerializer(ImageSerializer):
    upload_url = serializers.URLField()

    class Meta(ImageSerializer.Meta):
        fields = ImageSerializer.Meta.fields + ["upload_url"]
        read_only_fields = fields


class JobSerializer(serializers.ModelSerializer):
    class Meta:
        model = Job
        fields = [
            "id",
            "image",
            "model_version",
            "status",
            "result",
            "error_message",
            "started_at",
            "finished_at",
            "created_at",
        ]
        read_only_fields = fields


class JobCreateSerializer(serializers.Serializer):
    model_version_id = serializers.UUIDField(required=False)


class JobCallbackSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=["stil_done", "succeeded", "failed"])
    result = serializers.JSONField(required=False)
    error_message = serializers.CharField(required=False, allow_blank=True, default="")


class AnalysisShareSerializer(serializers.ModelSerializer):
    class Meta:
        model = AnalysisShare
        fields = [
            "id",
            "batch",
            "shared_by",
            "shared_to",
            "permission",
            "expires_at",
            "revoked_at",
            "created_at",
        ]
        read_only_fields = fields


class AnalysisShareCreateSerializer(serializers.Serializer):
    shared_to = serializers.PrimaryKeyRelatedField(queryset=Staff.objects.all())
    permission = serializers.ChoiceField(
        choices=AnalysisShare.Permission.choices, default=AnalysisShare.Permission.READ
    )
    expires_at = serializers.DateTimeField(required=False, allow_null=True, default=None)
