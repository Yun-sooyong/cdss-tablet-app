"""우체부가 쪽지를 발견하면 실제로 실행하는 함수.

5단계 — 결과/실패 보고와 생존 신고까지 붙여서 완성했다.
6단계(2026-08-04) — 일시적 실패(네트워크/타임아웃) 자동 재시도 + 친절한
   에러 메시지 추가.
"""
import os

from celery_app import app
from clients.mosec import call_segmentation
from clients.backend_api import report_stil_done, report_result, report_error, send_heartbeat
from pipeline.til_conformal import compute_stil_and_conformal
from pipeline.medgemma_genkit import generate_report
from pipeline.errors import TRANSIENT_EXCEPTIONS, friendly_error

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

        mc_stack, mask_key = call_segmentation(image_key, model_for_mosec, job_id=job_id)
        print(f"[run_job] 세그멘테이션 결과 모양: {mc_stack.shape}, mask_key={mask_key}")

        stats = compute_stil_and_conformal(mc_stack, conformal_q)
        stats["mask_key"] = mask_key  # 세그멘테이션 직후 바로 나오니 중간 보고에도 포함
        print(f"[run_job] sTIL/conformal 계산 결과: {stats}")

        report_stil_done(job_id, stats)  # 중간 보고 — MedGemma는 아직 시작 전

        report = generate_report(stats, mc_stack, job_id=job_id)
        print(f"[run_job] 판독 보고서: {report}")

        report_result(job_id, stats, report)
        return {**stats, "medgemma_report": report}

    except TRANSIENT_EXCEPTIONS as exc:
        # 네트워크 끊김·타임아웃처럼 "다시 하면 될 수도 있는" 실패만 재시도한다.
        # ValueError(잘못된 입력값) 같은 건 몇 번을 다시 해도 똑같이 실패하므로
        # 여기 안 걸리게 TRANSIENT_EXCEPTIONS을 좁게 잡아뒀다.
        if self.request.retries >= self.max_retries:
            print(f"[run_job] ⚠️ 재시도 {self.max_retries}회 소진, 최종 실패: {exc}")
            report_error(job_id, friendly_error(exc))
            raise
        wait = 10 * (self.request.retries + 1)  # 10초, 20초 순으로 점점 늘림
        print(f"[run_job] ⚠️ 일시적 실패 ({self.request.retries + 1}/{self.max_retries} 재시도, {wait}초 후 재시도): {exc}")
        raise self.retry(exc=exc, countdown=wait)

    except Exception as exc:
        print(f"[run_job] ⚠️ 실패: {exc}")
        report_error(job_id, friendly_error(exc))
        raise  # 삼키면 Celery가 성공으로 착각해서 재시도를 안 한다
