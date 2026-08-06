from django.conf import settings
from django.db.models import Count, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import get_staff_or_403
from apps.patients.models import Patient

from .models import AnalysisShare, Batch, Image, Job, ModelVersion, WorkerHeartbeat
from .serializers import (
    AnalysisShareCreateSerializer,
    AnalysisShareSerializer,
    BatchCreateSerializer,
    BatchSerializer,
    BatchStartSerializer,
    ImageSerializer,
    ImageUploadRequestSerializer,
    ImageUploadResponseSerializer,
    JobCallbackSerializer,
    JobCreateSerializer,
    JobSerializer,
    ModelVersionSerializer,
    UploadSignedUrlRequestSerializer,
    WorkerHeartbeatSerializer,
)
from .services import (
    apply_job_result,
    create_image_with_upload_url,
    dispatch_job,
)


def active_shares_for(staff):
    """staff가 공유받은, 아직 유효한(회수/만료 안 된) share 쿼리셋."""
    now = timezone.now()
    return AnalysisShare.objects.filter(shared_to=staff, revoked_at__isnull=True).filter(
        Q(expires_at__isnull=True) | Q(expires_at__gt=now)
    )


def with_batch_counts(queryset):
    """목록/상세 응답에 image_count·needs_review_count를 얹는다 — 최일운
    요청, 2026-08-05. 이게 없으면 프론트가 배치마다 상세 API를 또
    불러야 했고, 그때마다 BatchDetailView.get의 AuditLog READ가
    쌓이는 문제가 있었다(07 화면 2초 폴링이라 특히 심함).

    needs_review_count = 의료진 확인을 기다리는 job 수. 결과가 나온 job
    (stil_done/succeeded) 전부가 아니라, 그 중 판정이 ABSTAIN(유보)인
    것만 센다 — 화면이 말하는 "확인 필요"는 유보된 것뿐이라 결과 나온
    job 수를 그대로 쓰면 숫자가 안 맞았다 (최일운 요청, 2026-08-05.
    슬라이드 10장 중 8장 완료·2장 유보면 8이 아니라 2를 원함).
    """
    from .models import Job  # noqa: PLC0415 — 순환 임포트 회피

    return queryset.annotate(
        image_count=Count("images", distinct=True),
        needs_review_count=Count(
            "images__jobs",
            filter=Q(
                images__jobs__status__in=[Job.Status.STIL_DONE, Job.Status.SUCCEEDED]
            )
            & Q(images__jobs__result__decision="ABSTAIN"),
            distinct=True,
        ),
    )


def get_accessible_batch_or_404(staff, batch_id):
    """본인 batch + 공유받은 batch. 설계문서 6.7절/3.2-b."""
    shared_batch_ids = active_shares_for(staff).values_list("batch_id", flat=True)
    return get_object_or_404(
        with_batch_counts(Batch.objects),
        Q(created_by=staff) | Q(id__in=shared_batch_ids),
        id=batch_id,
        deleted_at__isnull=True,
    )


def get_own_batch_or_404(staff, batch_id):
    """본인 batch만. get_object_or_404를 그대로 쓰면 DRF 기본 문구
    "No Batch matches the given query."가 그대로 화면에 뜬다 — 소유자가
    아닌 배치를 공유하려 할 때 나오는 메시지라 한글로 바꿨다 (최일운
    요청, 2026-08-05)."""
    try:
        return Batch.objects.get(id=batch_id, created_by=staff)
    except Batch.DoesNotExist:
        raise NotFound("본인이 만든 배치만 공유할 수 있습니다.") from None


class ModelVersionListView(APIView):
    """업로드 화면의 '모델 선택' 드롭다운용 — 기본은 활성 모델만.

    ?include_inactive=true면 전체를 내려준다 — 예전 배치가 비활성화된
    모델로 돌아간 경우, 그 배치 상세에서 모델 이름을 찾으려면 비활성
    모델도 조회할 수 있어야 한다 (최일운 요청, 2026-08-05).
    """

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=ModelVersionSerializer(many=True))
    def get(self, request):
        versions = ModelVersion.objects.all()
        if request.query_params.get("include_inactive") != "true":
            versions = versions.filter(is_active=True)
        return Response(ModelVersionSerializer(versions.order_by("name"), many=True).data)


DEFAULT_BATCH_LIST_LIMIT = 50
MAX_BATCH_LIST_LIMIT = 200


class BatchListCreateView(APIView):
    """설계문서 3.2-b — 본인 batch + 공유받은 batch.

    목록이 쿼리 파라미터도 페이지네이션도 없이 통째로 내려가서, 배치가
    1000건을 넘으면 응답 한 번에 다 오고 화면이 1000행을 한꺼번에
    그리는 문제가 있었다 (최일운 요청, 2026-08-05). ?limit=/?offset=로
    페이지를 끊고, ?patient=/?status=/?date_from=/?date_to=/?q=로
    서버 필터·검색을 추가했다. patient.name은 암호화 컬럼이라 DB에서
    LIKE 검색이 안 되므로, ?q=는 chart_number는 DB에서, name은
    복호화한 뒤 파이썬에서 부분일치를 확인한다 — 환자 수가 배치 수보다
    훨씬 적다는 전제."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=BatchSerializer(many=True))
    def get(self, request):
        staff = get_staff_or_403(request.user)
        shared_batch_ids = active_shares_for(staff).values_list("batch_id", flat=True)
        batches = (
            with_batch_counts(Batch.objects)
            .select_related("patient")
            .filter(
                Q(created_by=staff) | Q(id__in=shared_batch_ids),
                deleted_at__isnull=True,
            )
            .distinct()
        )

        patient_id = request.query_params.get("patient")
        if patient_id:
            batches = batches.filter(patient_id=patient_id)

        # ?shared=true — 본인이 만든 배치 제외하고 "나한테 공유된 것"만.
        # 위에서 이미 본인+공유받은 걸로 좁혀놨으니, id__in=shared_batch_ids로
        # 한 번 더 좁히면 교집합(=공유받은 것만)이 된다.
        if request.query_params.get("shared", "").lower() == "true":
            batches = batches.filter(id__in=shared_batch_ids)

        status_filter = request.query_params.get("status")
        if status_filter:
            batches = batches.filter(status=status_filter)

        date_from = request.query_params.get("date_from")
        if date_from:
            batches = batches.filter(created_at__date__gte=date_from)

        date_to = request.query_params.get("date_to")
        if date_to:
            batches = batches.filter(created_at__date__lte=date_to)

        q = request.query_params.get("q")
        if q:
            chart_matched_ids = set(
                Patient.objects.filter(chart_number__icontains=q).values_list(
                    "id", flat=True
                )
            )
            name_matched_ids = {
                p.id
                for p in Patient.objects.only("id", "name")
                if q.lower() in (p.name or "").lower()
            }
            batches = batches.filter(
                patient_id__in=chart_matched_ids | name_matched_ids
            )

        batches = batches.order_by("-created_at")
        total_count = batches.count()

        try:
            limit = min(
                int(request.query_params.get("limit", DEFAULT_BATCH_LIST_LIMIT)),
                MAX_BATCH_LIST_LIMIT,
            )
            offset = int(request.query_params.get("offset", 0))
        except ValueError:
            raise ValidationError("limit/offset은 정수여야 합니다.") from None

        page = batches[offset : offset + limit]
        return Response(
            {
                "count": total_count,
                "limit": limit,
                "offset": offset,
                "results": BatchSerializer(page, many=True).data,
            }
        )

    @extend_schema(request=BatchCreateSerializer, responses=BatchSerializer)
    def post(self, request):
        staff = get_staff_or_403(request.user)
        serializer = BatchCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        batch = Batch.objects.create(
            created_by=staff, patient=serializer.validated_data["patient"]
        )
        return Response(BatchSerializer(batch).data, status=status.HTTP_201_CREATED)


class BatchDetailView(APIView):
    """설계문서 7.4절 — 배치 상세 (job 목록 포함) / 삭제. 본인 + 공유받은 batch만 조회,
    삭제는 본인 것만."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=BatchSerializer)
    def get(self, request, batch_id):
        staff = get_staff_or_403(request.user)
        batch = get_accessible_batch_or_404(staff, batch_id)

        if batch.patient_id:
            from apps.accounts.models import AuditLog
            from apps.common.audit import log_access

            log_access(
                request,
                AuditLog.Action.READ,
                target_table="patient",
                target_id=batch.patient_id,
                patient=batch.patient,
            )

        data = BatchSerializer(batch).data
        jobs = (
            Job.objects.filter(image__batch=batch)
            .select_related("image", "image__batch__patient")
            .order_by("-created_at")
        )
        data["jobs"] = JobSerializer(jobs, many=True).data
        return Response(data)

    @extend_schema(request=None, responses=None)
    def delete(self, request, batch_id):
        """리스트에서 삭제 — 설계문서 3.2-i. 물리 삭제 아니라 soft delete."""
        staff = get_staff_or_403(request.user)
        batch = get_object_or_404(
            Batch, id=batch_id, created_by=staff, deleted_at__isnull=True
        )
        batch.deleted_at = timezone.now()
        batch.save(update_fields=["deleted_at", "updated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)


class BatchImageUploadView(APIView):
    """POST /batches/{id}/images/. UploadSignedUrlView와 동일 로직 —
    저희가 먼저 만든 nested 경로, 설계문서엔 독립 경로(/uploads/signed-url)로
    돼 있어서 그것도 별도로 만들어뒀다. 둘 다 남겨둠(하위호환)."""

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

        image, upload_url, content_type = create_image_with_upload_url(batch, filename)
        data = ImageSerializer(image).data
        data["upload_url"] = upload_url
        data["upload_content_type"] = content_type
        return Response(data, status=status.HTTP_201_CREATED)


class UploadSignedUrlView(APIView):
    """설계문서 7.4절 — POST /uploads/signed-url. 독립 엔드포인트 버전."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(
        request=UploadSignedUrlRequestSerializer, responses=ImageUploadResponseSerializer
    )
    def post(self, request):
        staff = get_staff_or_403(request.user)
        serializer = UploadSignedUrlRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        batch = serializer.validated_data["batch"]
        if batch.created_by_id != staff.id:
            raise PermissionDenied("본인 batch에만 이미지를 추가할 수 있습니다.")

        image, upload_url, content_type = create_image_with_upload_url(
            batch, serializer.validated_data["original_filename"]
        )
        data = ImageSerializer(image).data
        data["upload_url"] = upload_url
        data["upload_content_type"] = content_type
        return Response(data, status=status.HTTP_201_CREATED)


class BatchStartView(APIView):
    """설계문서 7.4절 — POST /batches/{id}/start. 분석 시작.

    batch에 등록된 이미지 중 아직 job이 없는 것들에 대해 한 번에 job을
    만들어 큐에 등록한다 (기존 POST /images/{id}/jobs/는 이미지 하나씩
    개별 등록하는 하위 경로로 계속 남겨둠)."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=BatchStartSerializer, responses=BatchSerializer)
    def post(self, request, batch_id):
        staff = get_staff_or_403(request.user)
        batch = get_object_or_404(
            Batch, id=batch_id, created_by=staff, deleted_at__isnull=True
        )

        serializer = BatchStartSerializer(data=request.data)
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

        images_without_job = list(Image.objects.filter(batch=batch, jobs__isnull=True))
        if not images_without_job:
            return Response(
                {"detail": "새로 시작할 이미지가 없습니다."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # job을 전부 먼저 만든 뒤에 디스패치한다 — mock 모드는 동기 처리라,
        # 하나씩 만들면서 바로 처리하면 아직 안 만들어진 나머지 이미지를
        # "이미 다 끝남"으로 착각해 배치를 조기 완료 처리하는 버그가 생긴다.
        jobs = [
            Job.objects.create(image=image, model_version=model_version)
            for image in images_without_job
        ]

        batch.status = Batch.Status.PROCESSING
        batch.save(update_fields=["status", "updated_at"])

        for job in jobs:
            dispatch_job(job)

        batch.refresh_from_db()
        return Response(BatchSerializer(batch).data)


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


class JobListView(APIView):
    """GET /analysis/jobs/ — batch를 거치지 않고 job을 가로질러 조회.
    대시보드·09 검증 화면·사이드바 배지에서 필요 (최일운 요청, 2026-08-05).
    본인 batch + 공유받은 batch의 job만, get_accessible_batch_or_404와
    같은 접근 범위를 재사용한다."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=JobSerializer(many=True))
    def get(self, request):
        staff = get_staff_or_403(request.user)
        shared_batch_ids = active_shares_for(staff).values_list("batch_id", flat=True)
        jobs = (
            Job.objects.filter(
                Q(image__batch__created_by=staff) | Q(image__batch_id__in=shared_batch_ids),
                image__batch__deleted_at__isnull=True,
            )
            .select_related("image", "image__batch__patient")
            .distinct()
            .order_by("-created_at")
        )

        if request.query_params.get("needs_review") == "true":
            jobs = jobs.filter(status__in=[Job.Status.STIL_DONE, Job.Status.SUCCEEDED])

        return Response(JobSerializer(jobs, many=True).data)


class JobDetailView(APIView):
    """본인 batch + 공유받은 batch의 job만 조회 가능."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=JobSerializer)
    def get(self, request, job_id):
        staff = get_staff_or_403(request.user)
        job = get_object_or_404(Job, id=job_id)
        get_accessible_batch_or_404(staff, job.image.batch_id)
        return Response(JobSerializer(job).data)


class AnalysisShareListView(APIView):
    """GET /analysis/shares/?direction=sent|received — 공유 전체 목록.

    지금까지 특정 batch 밑(POST/GET .../shares/)으로만 생성·조회가
    됐는데, batch를 안 거치고 "내가 보낸 것/받은 것"을 한 번에 보는
    화면이 필요해서 추가 (최일운 요청, 2026-08-05).
    """

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=AnalysisShareSerializer(many=True))
    def get(self, request):
        staff = get_staff_or_403(request.user)
        direction = request.query_params.get("direction")
        if direction not in ("sent", "received"):
            raise ValidationError("direction 쿼리 파라미터는 sent 또는 received여야 합니다.")

        if direction == "sent":
            shares = AnalysisShare.objects.filter(shared_by=staff)
        else:
            shares = AnalysisShare.objects.filter(shared_to=staff)

        return Response(
            AnalysisShareSerializer(shares.order_by("-created_at"), many=True).data
        )


class BatchShareListCreateView(APIView):
    """설계문서 7.4절 — 공유. 소유자만 공유를 만들거나 현황을 볼 수 있다."""

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses=AnalysisShareSerializer(many=True))
    def get(self, request, batch_id):
        staff = get_staff_or_403(request.user)
        batch = get_own_batch_or_404(staff, batch_id)
        shares = AnalysisShare.objects.filter(batch=batch).order_by("-created_at")
        return Response(AnalysisShareSerializer(shares, many=True).data)

    @extend_schema(
        request=AnalysisShareCreateSerializer, responses=AnalysisShareSerializer
    )
    def post(self, request, batch_id):
        staff = get_staff_or_403(request.user)
        batch = get_own_batch_or_404(staff, batch_id)

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

        # Notification.Type.SHARE는 원래 있었는데 실제 발송 연결이 빠져있었다
        # (정다희, 2026-08-05 — 사용자 요청으로 연결).
        from apps.accounts.services import notify  # noqa: PLC0415 — 순환 임포트 회피

        notify(
            share.shared_to.user,
            "share",
            f"{staff.user.username}님이 분석 결과를 공유했습니다 (batch {batch.id}).",
            target_type="batch",
            target_id=batch.id,
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


class WorkerHeartbeatView(APIView):
    """설계문서 7.5절/2.5절 — POST /internal/workers/heartbeat. 워커 생존 신고."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    @extend_schema(request=WorkerHeartbeatSerializer, responses=None)
    def post(self, request):
        token = request.headers.get("X-Internal-Token", "")
        if not settings.INTERNAL_API_TOKEN or token != settings.INTERNAL_API_TOKEN:
            return Response(
                {"detail": "unauthorized"}, status=status.HTTP_401_UNAUTHORIZED
            )

        serializer = WorkerHeartbeatSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        WorkerHeartbeat.objects.update_or_create(
            worker_name=data["worker_name"],
            defaults={"version": data.get("version", "")},
        )
        return Response(status=status.HTTP_204_NO_CONTENT)
