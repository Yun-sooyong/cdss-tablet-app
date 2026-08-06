from rest_framework import serializers

from apps.patients.models import Patient
from apps.patients.serializers import PatientSummarySerializer
from apps.staff.models import Staff

from .models import AnalysisShare, Batch, Image, Job, JobReview, ModelVersion
from .services import build_mask_read_url, build_original_read_url


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
    # storage_key는 GCS 안의 키 문자열일 뿐 직접 열 수 있는 URL이 아니라서
    # 조회용 서명 URL을 따로 내려준다 (최일운 요청, 2026-08-05).
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Image
        fields = [
            "id",
            "batch",
            "storage_key",
            "image_url",
            "original_filename",
            "captured_at",
            "width",
            "height",
            "created_at",
        ]
        read_only_fields = fields

    def get_image_url(self, obj) -> str:
        return build_original_read_url(obj)


class ImageUploadRequestSerializer(serializers.Serializer):
    original_filename = serializers.CharField(max_length=255)


class ImageUploadResponseSerializer(ImageSerializer):
    upload_url = serializers.URLField()
    # 실제 PUT 요청에 이 값 그대로 Content-Type 헤더로 보내야 서명이 맞다
    # (2026-08-05 — 예전엔 항상 application/octet-stream으로 고정 서명해서
    # 업로드된 이미지가 그 타입으로 저장되고, 나중에 다시 불러올 때
    # 브라우저/Flutter가 이미지로 렌더링을 거부하는 문제가 있었음).
    upload_content_type = serializers.CharField()

    class Meta(ImageSerializer.Meta):
        fields = ImageSerializer.Meta.fields + ["upload_url", "upload_content_type"]
        read_only_fields = fields


class ImageSummarySerializer(serializers.ModelSerializer):
    """job 응답에 끼워 넣는 최소 이미지 정보 — image가 UUID만 있어서 화면에
    파일명 대신 UUID 앞 8자가 뜨던 문제 (최일운 요청, 2026-08-05).

    batch를 추가한다 — 결과 상세 화면의 브레드크럼이 배치를 되찾고
    (최일운 요청, 2026-08-05), GET /analysis/jobs/ 결과를 배치별로 묶어
    with_batch_counts() 없이도 배치당 확인 필요 수를 셀 수 있다."""

    class Meta:
        model = Image
        fields = ["id", "original_filename", "batch"]
        read_only_fields = fields


class JobReviewSerializer(serializers.ModelSerializer):
    class Meta:
        model = JobReview
        fields = ["id", "decision", "reason", "reviewed_by", "created_at"]
        read_only_fields = fields


class JobReviewCreateSerializer(serializers.Serializer):
    decision = serializers.ChoiceField(choices=JobReview.Decision.choices)
    reason = serializers.CharField()

    def validate_reason(self, value):
        if not value.strip():
            raise serializers.ValidationError("reason은 비어 있을 수 없습니다.")
        return value


class JobSerializer(serializers.ModelSerializer):
    """job은 patient FK가 없어 image.batch.patient를 타고 올라가 요약을
    붙인다 — 최일운 요청, 2026-08-04. 파일명만 보이던 07·08·09 화면에
    환자 맥락이 붙는다."""

    patient_summary = serializers.SerializerMethodField()
    image_summary = ImageSummarySerializer(source="image", read_only=True)
    original_url = serializers.SerializerMethodField()
    mask_url = serializers.SerializerMethodField()
    review = serializers.SerializerMethodField()

    class Meta:
        model = Job
        fields = [
            "id",
            "image",
            "image_summary",
            "original_url",
            "model_version",
            "status",
            "result",
            "mask_url",
            "error_message",
            "patient_summary",
            "review",
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

    def get_original_url(self, obj) -> str:
        return build_original_read_url(obj.image)

    def get_mask_url(self, obj) -> str | None:
        return build_mask_read_url(obj)

    def get_review(self, obj) -> dict | None:
        # JobReview.Meta.ordering = ["-created_at"]라 [0]이 항상 최신
        # 1건 — reviews가 prefetch_related로 캐시돼 있으면(목록 화면)
        # 추가 쿼리 없이 캐시에서 바로 나간다.
        reviews = list(obj.reviews.all())
        return JobReviewSerializer(reviews[0]).data if reviews else None


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
            "opinion",
            "expires_at",
            "revoked_at",
            "created_at",
        ]
        read_only_fields = fields


class AnalysisShareCreateSerializer(serializers.Serializer):
    shared_to = serializers.PrimaryKeyRelatedField(queryset=Staff.objects.all())
    opinion = serializers.CharField(
        max_length=200, required=False, allow_blank=True, default=""
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
