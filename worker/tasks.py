"""우체부가 쪽지를 발견하면 실제로 실행하는 함수.

4단계 — 판독 보고서 생성(지금은 가짜)까지 연결해서 전 구간을 완성했다.
"""
from celery_app import app
from clients.mosec_mock import call_segmentation
from pipeline.til_conformal import compute_stil_and_conformal
from pipeline.medgemma_mock import generate_report


@app.task(name="analysis.run_job", bind=True, max_retries=2)
def run_job(self, job_id, image_key, model_version_id, conformal_q):
    """
    이름(name="analysis.run_job")이 핵심이다.
    Django(접수처)가 정확히 이 이름으로 쪽지를 보내기 때문에,
    철자가 하나라도 다르면 쪽지는 영원히 도착하지 않는다 (에러도 안 남).
    """
    print(f"[run_job] 시작 — job_id={job_id}, model_version_id={model_version_id}")

    mc_stack = call_segmentation(image_key, model_version_id)
    print(f"[run_job] 세그멘테이션 결과 모양: {mc_stack.shape}")

    stats = compute_stil_and_conformal(mc_stack, conformal_q)
    print(f"[run_job] sTIL/conformal 계산 결과: {stats}")

    report = generate_report(stats)
    print(f"[run_job] 판독 보고서: {report}")

    return {**stats, "medgemma_report": report}
