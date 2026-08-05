from rest_framework import serializers

from apps.patients.models import Patient
from apps.patients.serializers import PatientSummarySerializer
from apps.staff.models import Staff

from .models import AnalysisShare, Batch, Image, Job, ModelVersion
from .services import build_mask_read_url


class ModelVersionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ModelVersion
        fields = [
            "id",
            "name",
            "version",
            "conformal_q",
            "is_active",
            "weight_key",
            "trained_at",
            "created_at",
        ]
        read_only_fields = fields


class BatchSerializer(serializers.ModelSerializer):
    """patient는 UUID FK 그대로 두고, patient_summary에 판독용 최소 정보
    (이름/생년월일/성별)를 같이 내려준다 — 최일운 요청, 2026-08-04.
    이 batch에 접근 가능한 staff한테만 내려가므로(view의 권한 체크가
    이미 됨) 별도 권한 분기는 필요 없다."""

    patient_summary = PatientSummarySerializer(source="patient", read_only=True)
    # with_batch_counts()로 annotate된 값 — 이 값 없이 만든 쿼리셋으로
    # 직렬화하면 AttributeError가 난다 (최일운 요청, 2026-08-05).
    image_count = serializers.IntegerField(read_only=True)
    needs_review_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Batch
        fields = [
            "id",
            "patient",
            "patient_summary",
            "status",
            "image_count",
            "needs_review_count",
            "created_by",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class BatchCreateSerializer(serializers.Serializer):
    patient_id = serializers.PrimaryKeyRelatedField(
        source="patient", queryset=Patient.objects.all()
    )


class ImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Image
        fields = [
            "id",
            "batch",
            "storage_key",
            "original_filename",
            "captured_at",
            "width",
            "height",
            "created_at",
        ]
        read_only_fields = fields


class ImageUploadRequestSerializer(serializers.Serializer):
    original_filename = serializers.CharField(max_length=255)


class ImageUploadResponseSerializer(ImageSerializer):
    upload_url = serializers.URLField()

    class Meta(ImageSerializer.Meta):
        fields = ImageSerializer.Meta.fields + ["upload_url"]
        read_only_fields = fields


class ImageSummarySerializer(serializers.ModelSerializer):
    """job 응답에 끼워 넣는 최소 이미지 정보 — image가 UUID만 있어서 화면에
    파일명 대신 UUID 앞 8자가 뜨던 문제 (최일운 요청, 2026-08-05)."""

    class Meta:
        model = Image
        fields = ["id", "original_filename"]
        read_only_fields = fields


class JobSerializer(serializers.ModelSerializer):
    """job은 patient FK가 없어 image.batch.patient를 타고 올라가 요약을
    붙인다 — 최일운 요청, 2026-08-04. 파일명만 보이던 07·08·09 화면에
    환자 맥락이 붙는다."""

    patient_summary = serializers.SerializerMethodField()
    image_summary = ImageSummarySerializer(source="image", read_only=True)
    mask_url = serializers.SerializerMethodField()

    class Meta:
        model = Job
        fields = [
            "id",
            "image",
            "image_summary",
            "model_version",
            "status",
            "result",
            "mask_url",
            "error_message",
            "patient_summary",
            "started_at",
            "finished_at",
            "created_at",
        ]
        read_only_fields = fields

    def get_patient_summary(self, obj) -> dict | None:
        patient = obj.image.batch.patient
        if patient is None:
            return None
        return PatientSummarySerializer(patient).data

    def get_mask_url(self, obj) -> str | None:
        return build_mask_read_url(obj)


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


class UploadSignedUrlRequestSerializer(serializers.Serializer):
    batch_id = serializers.PrimaryKeyRelatedField(
        source="batch", queryset=Batch.objects.filter(deleted_at__isnull=True)
    )
    original_filename = serializers.CharField(max_length=255)


class BatchStartSerializer(serializers.Serializer):
    model_version_id = serializers.UUIDField(required=False)


class WorkerHeartbeatSerializer(serializers.Serializer):
    worker_name = serializers.CharField(max_length=50)
    version = serializers.CharField(max_length=20, required=False, allow_blank=True, default="")
