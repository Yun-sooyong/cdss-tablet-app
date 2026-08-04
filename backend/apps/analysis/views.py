import uuid

from django.conf import settings
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import get_staff_or_403

from .models import AnalysisShare, Batch, Image, Job, ModelVersion
from .serializers import (
    AnalysisShareCreateSerializer,
    AnalysisShareSerializer,
    BatchSerializer,
    ImageSerializer,
    ImageUploadRequestSerializer,
    ImageUploadResponseSerializer,
    JobCallbackSerializer,
    JobCreateSerializer,
    JobSerializer,
    ModelVersionSerializer,
)
from .services import apply_job_result, build_upload_url, dispatch_job


def active_shares_for(staff):
    """staff가 공유받은, 아직 유효한(회수/만료 안 된) share 쿼리셋."""
    now = timezone.now()
    return AnalysisShare.objects.filter(shared_to=staff, revoked_at__isnull=True).filter(
        Q(expires_at__isnull=True) | Q(expires_at__gt=now)
    )


def get_accessible_batch_or_404(staff, batch_id):
    """본인 batch + 공유받은 batch. 설계문서 6.7절/3.2-b."""
    shared_batch_ids = active_shares_for(staff).values_list("batch_id", flat=True)
    return get_object_or_404(
        Batch, Q(created_by=staff) | Q(id__in=shared_batch_ids), id=batch_id
    )


class ModelVersionListView(APIView):
    """업로드 화면의 '모델 선택' 드롭다운용 — 활성 모델 버전 목록."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=ModelVersionSerializer(many=True))
    def get(self, request):
        versions = ModelVersion.objects.filter(is_active=True).order_by("name")
        return Response(ModelVersionSerializer(versions, many=True).data)


class BatchListCreateView(APIView):
    """설계문서 3.2-b — 본인 batch + 공유받은 batch."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=BatchSerializer(many=True))
    def get(self, request):
        staff = get_staff_or_403(request.user)
        shared_batch_ids = active_shares_for(staff).values_list("batch_id", flat=True)
        batches = Batch.objects.filter(
            Q(created_by=staff) | Q(id__in=shared_batch_ids)
        ).distinct().order_by("-created_at")
        return Response(BatchSerializer(batches, many=True).data)

    @extend_schema(request=None, responses=BatchSerializer)
    def post(self, request):
        staff = get_staff_or_403(request.user)
        batch = Batch.objects.create(created_by=staff)
        return Response(BatchSerializer(batch).data, status=status.HTTP_201_CREATED)


class BatchDetailView(APIView):
    """설계문서 7.4절 — 배치 상세 (job 목록 포함). 본인 + 공유받은 batch만."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=BatchSerializer)
    def get(self, request, batch_id):
        staff = get_staff_or_403(request.user)
        batch = get_accessible_batch_or_404(staff, batch_id)
        data = BatchSerializer(batch).data
        jobs = Job.objects.filter(image__batch=batch).order_by("-created_at")
        data["jobs"] = JobSerializer(jobs, many=True).data
        return Response(data)


class BatchImageUploadView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(
        request=ImageUploadRequestSerializer, responses=ImageUploadResponseSerializer
    )
    def post(self, request, batch_id):
        staff = get_staff_or_403(request.user)
        batch = get_object_or_404(Batch, id=batch_id, created_by=staff)

        serializer = ImageUploadRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        filename = serializer.validated_data["original_filename"]

        storage_key = f"uploads/{batch.id}/{uuid.uuid4()}_{filename}"
        image = Image.objects.create(
            batch=batch, storage_key=storage_key, original_filename=filename
        )
        data = ImageSerializer(image).data
        data["upload_url"] = build_upload_url(storage_key)
        return Response(data, status=status.HTTP_201_CREATED)


class ImageJobCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=JobCreateSerializer, responses=JobSerializer)
    def post(self, request, image_id):
        staff = get_staff_or_403(request.user)
        image = get_object_or_404(Image, id=image_id, batch__created_by=staff)

        serializer = JobCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        model_version_id = serializer.validated_data.get("model_version_id")

        if model_version_id:
            model_version = get_object_or_404(
                ModelVersion, id=model_version_id, is_active=True
            )
        else:
            model_version = (
                ModelVersion.objects.filter(is_active=True)
                .order_by("-created_at")
                .first()
            )
            if model_version is None:
                return Response(
                    {"detail": "사용 가능한 모델 버전이 없습니다."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        job = Job.objects.create(image=image, model_version=model_version)
        dispatch_job(job)
        job.refresh_from_db()
        return Response(JobSerializer(job).data, status=status.HTTP_201_CREATED)


class JobDetailView(APIView):
    """본인 batch + 공유받은 batch의 job만 조회 가능."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=JobSerializer)
    def get(self, request, job_id):
        staff = get_staff_or_403(request.user)
        job = get_object_or_404(Job, id=job_id)
        get_accessible_batch_or_404(staff, job.image.batch_id)
        return Response(JobSerializer(job).data)


class BatchShareListCreateView(APIView):
    """설계문서 7.4절 — 공유. 소유자만 공유를 만들거나 현황을 볼 수 있다."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=AnalysisShareSerializer(many=True))
    def get(self, request, batch_id):
        staff = get_staff_or_403(request.user)
        batch = get_object_or_404(Batch, id=batch_id, created_by=staff)
        shares = AnalysisShare.objects.filter(batch=batch).order_by("-created_at")
        return Response(AnalysisShareSerializer(shares, many=True).data)

    @extend_schema(
        request=AnalysisShareCreateSerializer, responses=AnalysisShareSerializer
    )
    def post(self, request, batch_id):
        staff = get_staff_or_403(request.user)
        batch = get_object_or_404(Batch, id=batch_id, created_by=staff)

        serializer = AnalysisShareCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        share = AnalysisShare.objects.create(
            batch=batch,
            shared_by=staff,
            shared_to=data["shared_to"],
            permission=data["permission"],
            expires_at=data["expires_at"],
        )
        return Response(
            AnalysisShareSerializer(share).data, status=status.HTTP_201_CREATED
        )


class ShareRevokeView(APIView):
    """설계문서 7.4절 — 공유 회수. revoked_at 기록(물리 삭제 아님)."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=None, responses=AnalysisShareSerializer)
    def delete(self, request, share_id):
        staff = get_staff_or_403(request.user)
        share = get_object_or_404(AnalysisShare, id=share_id)
        if share.shared_by_id != staff.id:
            raise PermissionDenied("본인이 공유한 건만 회수할 수 있습니다.")

        share.revoked_at = timezone.now()
        share.save(update_fields=["revoked_at", "updated_at"])
        return Response(AnalysisShareSerializer(share).data)


class JobCallbackView(APIView):
    """워커가 결과를 보고하는 엔드포인트. 환자 정보는 담기지 않는다 (README 6절)."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    @extend_schema(request=JobCallbackSerializer, responses=JobSerializer)
    def post(self, request, job_id):
        token = request.headers.get("X-Internal-Token", "")
        if not settings.INTERNAL_API_TOKEN or token != settings.INTERNAL_API_TOKEN:
            return Response(
                {"detail": "unauthorized"}, status=status.HTTP_401_UNAUTHORIZED
            )

        job = get_object_or_404(Job, id=job_id)
        serializer = JobCallbackSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        apply_job_result(job, **serializer.validated_data)
        return Response(JobSerializer(job).data)
