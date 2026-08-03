"""우체부가 쪽지를 발견하면 실제로 실행하는 함수.

지금은 안이 거의 비어 있다 — "쪽지가 오면 이 함수가 실행되는가"만 확인하는 단계.
sTIL 계산, MedGemma 리포트는 3~4단계에서 이 안에 채워 넣는다.
"""
from celery_app import app
from clients.mosec_mock import call_segmentation


@app.task(name="analysis.run_job", bind=True, max_retries=2)
def run_job(self, job_id, image_key, model_version_id, conformal_q):
    """
    이름(name="analysis.run_job")이 핵심이다.
    Django(접수처)가 정확히 이 이름으로 쪽지를 보내기 때문에,
    철자가 하나라도 다르면 쪽지는 영원히 도착하지 않는다 (에러도 안 남).
    """
    print(f"[run_job] 시작 — job_id={job_id}, model_version_id={model_version_id}")

    mc_stack = call_segmentation(image_key, model_version_id)
    print(f"[run_job] 가짜 분석 결과 모양: {mc_stack.shape}")

    return "여기까지 정상 동작 확인"
