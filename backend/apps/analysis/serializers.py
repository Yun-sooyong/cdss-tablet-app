from rest_framework import serializers

from .models import Batch, Image, Job


class BatchSerializer(serializers.ModelSerializer):
    class Meta:
        model = Batch
        fields = ["id", "status", "created_by", "created_at", "updated_at"]
        read_only_fields = fields


class ImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Image
        fields = ["id", "batch", "storage_key", "original_filename", "created_at"]
        read_only_fields = fields


class ImageUploadRequestSerializer(serializers.Serializer):
    original_filename = serializers.CharField(max_length=255)


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
    status = serializers.ChoiceField(choices=["succeeded", "failed"])
    result = serializers.JSONField(required=False)
    error_message = serializers.CharField(required=False, allow_blank=True, default="")
