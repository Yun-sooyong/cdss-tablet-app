import uuid

from django.conf import settings
from django.utils import timezone


def build_upload_url(storage_key: str) -> str:
    """이미지 업로드용 서명 URL 발급.

    settings.GCS_BUCKET이 비어있으면(로컬 등 GCS 미설정 환경) mock URL을
    돌려준다. Cloud Run은 JSON 키 파일이 없으므로(조직 정책으로 서비스
    계정 키 발급이 막혀있음 — worker/INTERFACE.md 2절과 동일한 이유),
    IAM SignBlob API로 서명한다. 이 서비스 계정 자신에게
    roles/iam.serviceAccountTokenCreator 권한이 있어야 동작한다.
    """
    if not settings.GCS_BUCKET:
        return f"https://mock-upload.local/{storage_key}"

    from datetime import timedelta  # noqa: PLC0415

    import google.auth  # noqa: PLC0415
    from google.auth import iam  # noqa: PLC0415
    from google.auth.transport import requests as gauth_requests  # noqa: PLC0415
    from google.cloud import storage  # noqa: PLC0415
    from google.oauth2 import service_account  # noqa: PLC0415

    credentials, _ = google.auth.default()
    auth_request = gauth_requests.Request()
    credentials.refresh(auth_request)

    signer = iam.Signer(auth_request, credentials, credentials.service_account_email)
    signing_credentials = service_account.Credentials(
        signer,
        credentials.service_account_email,
        token_uri="https://oauth2.googleapis.com/token",
    )

    client = storage.Client(credentials=credentials)
    blob = client.bucket(settings.GCS_BUCKET).blob(storage_key)

    return blob.generate_signed_url(
        version="v4",
        expiration=timedelta(minutes=15),
        method="PUT",
        content_type="application/octet-stream",
        credentials=signing_credentials,
    )


def create_image_with_upload_url(batch, filename: str):
    """batch에 이미지 레코드를 만들고 업로드 URL을 발급한다.

    BatchImageUploadView(POST /batches/{id}/images/)와
    UploadSignedUrlView(POST /uploads/signed-url/) 둘 다 이 로직을 쓴다
    — 전자는 우리가 처음에 만든 경로, 후자는 설계문서 7.4절에 명시된
    독립 엔드포인트. 프론트가 어느 쪽을 쓰든 동작은 같다.
    """
    from .models import Image  # noqa: PLC0415 — 순환 임포트 회피

    storage_key = f"uploads/{batch.id}/{uuid.uuid4()}_{filename}"
    image = Image.objects.create(
        batch=batch, storage_key=storage_key, original_filename=filename
    )
    return image, build_upload_url(storage_key)


def apply_job_result(job, status, result=None, error_message=""):
    """콜백 결과를 job에 반영한다.

    워커가 stil_done -> succeeded 두 번에 걸쳐 콜백을 보내므로(2026-08-03
    박검모 확정), 두 번째 콜백의 result를 기존 결과에 덮어쓰지 않고
    병합(merge)한다. finished_at은 최종 상태(succeeded/failed)에서만 찍는다.
    """
    job.status = status
    if result:
        merged = dict(job.result or {})
        merged.update(result)
        job.result = merged
    job.error_message = error_message
    if status in (job.Status.SUCCEEDED, job.Status.FAILED):
        job.finished_at = timezone.now()
    job.save(
        update_fields=["status", "result", "error_message", "finished_at", "updated_at"]
    )

    if status in (job.Status.SUCCEEDED, job.Status.FAILED):
        _maybe_finish_batch(job)

    return job


def _maybe_finish_batch(job):
    """batch의 모든 job이 끝났으면 batch.status를 갱신하고 알림을 한 번만
    보낸다 — 설계문서 9장: "배치 완료 시점에 FCM 발송, notification에도
    기록". job마다 보내면 이미지 여러 장짜리 batch에서 중복 알림이 간다."""
    from .models import Batch, Job  # noqa: PLC0415 — 순환 임포트 회피

    batch = job.image.batch
    unfinished = (
        Job.objects.filter(image__batch=batch)
        .exclude(status__in=[Job.Status.SUCCEEDED, Job.Status.FAILED])
        .exists()
    )
    if unfinished:
        return

    any_failed = Job.objects.filter(
        image__batch=batch, status=Job.Status.FAILED
    ).exists()
    batch.status = Batch.Status.FAILED if any_failed else Batch.Status.DONE
    batch.save(update_fields=["status", "updated_at"])

    from apps.accounts.services import notify  # noqa: PLC0415 — 순환 임포트 회피

    notify(
        batch.created_by.user,
        "analysis_done",
        f"분석이 완료됐습니다 (batch {batch.id}).",
        target_type="batch",
        target_id=batch.id,
    )


def dispatch_job(job):
    """job을 워커 큐에 등록한다.

    USE_MOCK_INFERENCE=true면 실제 Celery/Redis 없이 워커의 2단계 콜백
    (stil_done -> succeeded)을 그대로 흉내내서 '로그인 -> 업로드 -> batch
    -> 큐 등록 -> 워커 -> 콜백 -> 조회' 전 구간을 로컬에서 검증할 수 있게
    한다.
    """
    job.status = job.Status.RUNNING
    job.started_at = timezone.now()
    job.save(update_fields=["status", "started_at", "updated_at"])

    if settings.USE_MOCK_INFERENCE:
        # 실제 워커(박검모) 출력 키/형식에 맞춘 mock. worker/INTERFACE.md 참고.
        stil_result = {
            "stil_value": 42.0,  # 0~100 스케일
            "sigma": 5.0,
            "class_composition": {
                "tumor": 45.2,
                "stroma": 28.1,
                "immune": 15.3,
                "necrosis": 6.8,
                "other": 4.6,
            },
            "lower": 37.0,
            "upper": 47.0,
            "abstain": False,
            "decision": "LOW",  # LOW | HIGH | ABSTAIN
            "n_valid": 128,
            "cp_value": 0.87,
        }
        apply_job_result(job, status=job.Status.STIL_DONE, result=stil_result)

        medgemma_result = {
            "medgemma_report": {"summary": "mock report", "generation_failed": False},
        }
        apply_job_result(job, status=job.Status.SUCCEEDED, result=medgemma_result)
        return

    from config.celery import app  # noqa: PLC0415 — 실제 큐 연동 시에만 필요

    app.send_task(
        "analysis.run_job",
        kwargs={
            "job_id": str(job.id),
            "image_key": job.image.storage_key,
            "model_version_id": str(job.model_version.id),
            "model_name": job.model_version.name,
            "conformal_q": job.model_version.conformal_q,
        },
        queue="gpu",
    )
