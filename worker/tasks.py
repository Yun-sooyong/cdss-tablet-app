"""우체부가 쪽지를 발견하면 실제로 실행하는 함수.

5단계 — 결과/실패 보고와 생존 신고까지 붙여서 완성했다.
"""
import os

from celery_app import app
from clients.mosec import call_segmentation
from clients.backend_api import report_stil_done, report_result, report_error, send_heartbeat
from pipeline.til_conformal import compute_stil_and_conformal
from pipeline.medgemma_genkit import generate_report

WORKER_NAME = os.environ.get("WORKER_NAME", "local-test")


@app.task(name="analysis.run_job", bind=True, max_retries=2)
def run_job(self, job_id, image_key, conformal_q, model_version_id=None, model_name=None):
    """
    이름(name="analysis.run_job")이 핵심이다.
    Django(접수처)가 정확히 이 이름으로 쪽지를 보내기 때문에,
    철자가 하나라도 다르면 쪽지는 영원히 도착하지 않는다 (에러도 안 남).

    ⚠️ 2026-08-03: model_name이 kwargs에 추가됐다 (정다희 반영) — Mosec이
       "unet_v1" 같은 이름 문자열로 모델을 찾는데 model_version_id(UUID)로는
       못 찾던 문제의 해결. model_version_id는 하위 호환을 위해 남겨두되
       필수는 아니게 바꿨다.
    """
    send_heartbeat(WORKER_NAME)
    model_for_mosec = model_name or model_version_id
    print(f"[run_job] 시작 — job_id={job_id}, model_name={model_name}, model_version_id={model_version_id}")

    try:
        if conformal_q is None:
            # 이 모델이 아직 보정 안 됐을 가능성 — 여기서 막지 않으면
            # 계산 중간에 알 수 없는 에러로 죽어서 원인 찾기가 더 어려워진다.
            raise ValueError("conformal_q가 없습니다 — 이 모델은 아직 보정되지 않았을 수 있습니다")

        mc_stack = call_segmentation(image_key, model_for_mosec, job_id=job_id)
        print(f"[run_job] 세그멘테이션 결과 모양: {mc_stack.shape}")

        stats = compute_stil_and_conformal(mc_stack, conformal_q)
        print(f"[run_job] sTIL/conformal 계산 결과: {stats}")

        report_stil_done(job_id, stats)  # 중간 보고 — MedGemma는 아직 시작 전

        report = generate_report(stats, mc_stack, job_id=job_id)
        print(f"[run_job] 판독 보고서: {report}")

        report_result(job_id, stats, report)
        return {**stats, "medgemma_report": report}

    except Exception as exc:
        print(f"[run_job] ⚠️ 실패: {exc}")
        report_error(job_id, str(exc))
        raise  # 삼키면 Celery가 성공으로 착각해서 재시도를 안 한다
