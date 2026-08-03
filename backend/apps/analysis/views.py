import uuid

from django.conf import settings
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Batch, Image, Job, ModelVersion
from .serializers import (
    BatchSerializer,
    ImageSerializer,
    ImageUploadRequestSerializer,
    ImageUploadResponseSerializer,
    JobCallbackSerializer,
    JobCreateSerializer,
    JobSerializer,
)
from .services import apply_job_result, build_upload_url, dispatch_job


def get_staff_or_403(user):
    staff = getattr(user, "staff", None)
    if staff is None:
        raise PermissionDenied("의료진(staff) 계정이 아닙니다.")
    return staff


class BatchListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=BatchSerializer(many=True))
    def get(self, request):
        staff = get_staff_or_403(request.user)
        batches = Batch.objects.filter(created_by=staff).order_by("-created_at")
        return Response(BatchSerializer(batches, many=True).data)

    @extend_schema(request=None, responses=BatchSerializer)
    def post(self, request):
        staff = get_staff_or_403(request.user)
        batch = Batch.objects.create(created_by=staff)
        return Response(BatchSerializer(batch).data, status=status.HTTP_201_CREATED)


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

        storage_key = f"batches/{batch.id}/{uuid.uuid4()}_{filename}"
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
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=JobSerializer)
    def get(self, request, job_id):
        staff = get_staff_or_403(request.user)
        job = get_object_or_404(Job, id=job_id, image__batch__created_by=staff)
        return Response(JobSerializer(job).data)


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
