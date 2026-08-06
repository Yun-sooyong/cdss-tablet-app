import mimetypes
import uuid

from django.conf import settings
from django.utils import timezone

from apps.common.gcs import generate_signed_url


def build_upload_url(storage_key: str, content_type: str = "application/octet-stream") -> str:
    """이미지 업로드용 서명 URL(PUT) 발급.

    content_type을 서명에 그대로 묶기 때문에, 클라이언트가 실제 PUT
    요청에서 이 값과 정확히 같은 Content-Type 헤더를 보내야 한다(안
    맞으면 403). GCS는 업로드 시 받은 content-type을 그대로 저장하고
    나중에 GET할 때도 그걸 돌려주므로, 여기서 실제 이미지 타입을
    보내지 않으면(예: 예전처럼 고정값 application/octet-stream) 원본
    이미지를 다시 불러올 때 브라우저/Flutter가 이미지로 렌더링을
    거부하는 문제가 생긴다 (2026-08-05, 태블릿 화면 원본 로딩 실패로
    발견 — 응답의 upload_content_type 필드를 그대로 PUT 헤더에 써야 함).
    """
    return generate_signed_url(storage_key, method="PUT", content_type=content_type)


def build_mask_read_url(job) -> str | None:
    """분석 결과 마스크 이미지 조회용 서명 URL(GET).

    검모님 워커가 마스크를 masks/{job_id}.png 경로에 직접 업로드하기로
    확정 (2026-08-05) — job_id로 결정되는 경로라 result JSON에 키를
    별도로 담아 보낼 필요가 없다. sTIL 단계(stil_done)부터 파일이 있을
    수 있으므로 대기/실패 상태에서는 URL을 만들지 않는다(있지도 않은
    파일에 서명해봐야 프론트가 괜히 404만 본다).
    """
    from .models import Job  # noqa: PLC0415 — 순환 임포트 회피

    if job.status not in (Job.Status.STIL_DONE, Job.Status.SUCCEEDED):
        return None
    return generate_signed_url(f"masks/{job.id}.png", method="GET")


def build_original_read_url(image) -> str:
    """원본 슬라이드 이미지 조회용 서명 URL(GET).

    업로드용 서명 URL(PUT)은 있었는데 다시 불러와서 보는 용도(GET)가
    빠져있었다 — 최일운·윤수용 요청, 2026-08-05. storage_key 자체는
    GCS 버킷 안의 키 문자열일 뿐이라 브라우저/앱에서 직접 열 수 없다.
    mask_url과 달리 상태 제약 없이 업로드 직후부터 항상 유효하다.
    """
    return generate_signed_url(image.storage_key, method="GET")


def create_image_with_upload_url(batch, filename: str):
    """batch에 이미지 레코드를 만들고 업로드 URL을 발급한다.

    BatchImageUploadView(POST /batches/{id}/images/)와
    UploadSignedUrlView(POST /uploads/signed-url/) 둘 다 이 로직을 쓴다
    — 전자는 우리가 처음에 만든 경로, 후자는 설계문서 7.4절에 명시된
    독립 엔드포인트. 프론트가 어느 쪽을 쓰든 동작은 같다.
    """
    from .models import Image  # noqa: PLC0415 — 순환 임포트 회피

    storage_key = f"uploads/{batch.id}/{uuid.uuid4()}_{filename}"
    content_type = mimetypes.guess_type(filename)[0] or "application/octet-stream"
    image = Image.objects.create(
        batch=batch, storage_key=storage_key, original_filename=filename
    )
    return image, build_upload_url(storage_key, content_type=content_type), content_type


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
