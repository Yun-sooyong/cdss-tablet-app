from django.conf import settings
from django.utils import timezone


def build_upload_url(storage_key: str) -> str:
    """이미지 업로드용 URL 발급.

    실제로는 GCS 서명 URL을 발급해야 하지만, 로컬/데모 환경에서는
    GCS 연동 없이 흐름을 검증할 수 있도록 mock URL을 돌려준다.
    """
    if settings.USE_MOCK_INFERENCE:
        return f"https://mock-upload.local/{storage_key}"
    raise NotImplementedError("GCS 서명 URL 연동은 아직 구현되지 않았습니다.")


def apply_job_result(job, status, result=None, error_message=""):
    job.status = status
    job.result = result
    job.error_message = error_message
    job.finished_at = timezone.now()
    job.save(
        update_fields=["status", "result", "error_message", "finished_at", "updated_at"]
    )
    return job


def dispatch_job(job):
    """job을 워커 큐에 등록한다.

    USE_MOCK_INFERENCE=true면 실제 Celery/Redis 없이 즉시 성공 콜백을 흉내내서
    '로그인 -> 업로드 -> batch -> 큐 등록 -> 워커 -> 콜백 -> 조회' 전 구간을
    로컬에서 검증할 수 있게 한다.
    """
    job.status = job.Status.RUNNING
    job.started_at = timezone.now()
    job.save(update_fields=["status", "started_at", "updated_at"])

    if settings.USE_MOCK_INFERENCE:
        # 실제 워커(박검모) 출력 키/형식에 맞춘 mock. worker/INTERFACE.md 참고.
        mock_result = {
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
            "medgemma_report": {"summary": "mock report", "generation_failed": False},
        }
        apply_job_result(job, status=job.Status.SUCCEEDED, result=mock_result)
        return

    from config.celery import app  # noqa: PLC0415 — 실제 큐 연동 시에만 필요

    app.send_task(
        "analysis.run_job",
        kwargs={
            "job_id": str(job.id),
            "image_key": job.image.storage_key,
            "model_version_id": str(job.model_version.id),
            "conformal_q": job.model_version.conformal_q,
        },
        queue="gpu",
    )
