"""tasks.py(run_job) 검증 — 성공 경로와 실패 경로가 올바른 순서로
콜백을 보내는지 확인한다. Redis/Celery 자체는 필요 없다 —
run_job.run(...)으로 함수 알맹이만 직접 실행해서 본다.

⚠️ 2026-08-05: call_segmentation/generate_report를 mock으로 흉내낸다.
   원래 tasks.py가 clients.mosec_mock(가짜 현미경)을 쓰던 시절엔 이 mock이
   필요 없었는데, 진짜 Mosec(clients.mosec)으로 바꾸면서 이 테스트가 실제
   네트워크 호출을 하게 돼버렸었다 (Mosec 서버가 떠있어야만 통과되고,
   fake.png 같은 존재하지 않는 이미지라 422로 깨졌다). 진짜 서버 유무와
   무관하게 항상 같은 결과로 검증되도록 다시 격리시켰다.
"""
from unittest.mock import patch

import numpy as np

from tasks import run_job

FAKE_MC_STACK = np.zeros((20, 64, 64), dtype=np.uint8)
FAKE_MC_STACK[:, 32:, :] = 2  # 아래쪽 절반은 immune — sTIL 계산 가능하게
FAKE_MASK_KEY = "masks/job-fake.png"

# 2026-08-05: call_segmentation()이 (mc_stack, mask_key) 튜플을 반환하도록
# 바뀌었다 — 프론트엔드 오버레이용 마스크 이미지 GCS 경로를 같이 실어보내려고.
FAKE_SEGMENTATION_RESULT = (FAKE_MC_STACK, FAKE_MASK_KEY)

FAKE_REPORT = {
    "segmentation_summary": "가짜 요약",
    "findings": "가짜 소견",
    "ai_opinion": "가짜 의견",
    "disclaimer": "가짜 안내문",
    "opinion_note": "가짜 의견 안내문",
    "generation_failed": False,
}


def test_success_path_calls_stil_done_then_result():
    with patch("tasks.call_segmentation", return_value=FAKE_SEGMENTATION_RESULT), \
         patch("tasks.generate_report", return_value=FAKE_REPORT), \
         patch("tasks.report_stil_done") as mock_stil_done, \
         patch("tasks.report_result") as mock_result, \
         patch("tasks.report_error") as mock_error, \
         patch("tasks.send_heartbeat"):
        result = run_job.run(
            job_id="job-1", image_key="fake.png",
            model_version_id="v1", conformal_q=19.63,
        )

    mock_stil_done.assert_called_once()
    mock_result.assert_called_once()
    mock_error.assert_not_called()  # 성공 케이스라 에러 보고는 없어야 함

    assert mock_stil_done.call_args.args[0] == "job-1"
    assert result["decision"] in ("LOW", "HIGH", "ABSTAIN")
    assert "medgemma_report" in result, "최종 반환값에 판독 보고서가 빠짐"
    assert result["mask_key"] == FAKE_MASK_KEY, "최종 반환값에 mask_key가 안 실림"


def test_stil_done_is_reported_before_medgemma_report_generated():
    """중간 보고(stil_done)에는 medgemma_report가 아직 없어야 한다.
    이게 섞이면 '계산 끝나자마자 먼저 알린다'는 의도가 깨진 것이다.
    반면 mask_key는 세그멘테이션 직후 바로 나오니 중간 보고에도 있어야 한다."""
    with patch("tasks.call_segmentation", return_value=FAKE_SEGMENTATION_RESULT), \
         patch("tasks.generate_report", return_value=FAKE_REPORT), \
         patch("tasks.report_stil_done") as mock_stil_done, \
         patch("tasks.report_result"), \
         patch("tasks.report_error"), \
         patch("tasks.send_heartbeat"):
        run_job.run(job_id="job-2", image_key="fake.png", model_version_id="v1", conformal_q=19.63)

    stil_done_stats = mock_stil_done.call_args.args[1]
    assert "medgemma_report" not in stil_done_stats, "중간 보고에 리포트가 이미 섞여 들어감"
    assert stil_done_stats["mask_key"] == FAKE_MASK_KEY, "중간 보고에 mask_key가 빠짐"


def test_missing_conformal_q_reports_error_and_reraises():
    """conformal_q가 없으면(모델 미보정) 에러 보고 후 예외를 다시 던져야 한다.
    삼키면 Celery가 성공으로 착각해서 재시도를 안 한다."""
    with patch("tasks.report_stil_done"), \
         patch("tasks.report_result") as mock_result, \
         patch("tasks.report_error") as mock_error, \
         patch("tasks.send_heartbeat"):

        raised = False
        try:
            run_job.run(job_id="job-3", image_key="fake.png", model_version_id="v1", conformal_q=None)
        except ValueError:
            raised = True

    assert raised, "예외가 삼켜짐 — 재시도 기회가 사라짐"
    mock_error.assert_called_once()
    assert mock_error.call_args.args[0] == "job-3"
    assert "conformal_q" in mock_error.call_args.args[1]
    mock_result.assert_not_called()  # 실패했으니 정상 완료 보고는 없어야 함


def test_connection_error_reports_friendly_message_when_retries_exhausted():
    """재시도 횟수가 소진된 상태(max_retries=0으로 낮춰서 즉시 소진을 흉내냄)
    라면, 예외 원문이 아니라 친절한 한국어 문구로 report_error가 불려야 한다."""
    import requests

    with patch("tasks.call_segmentation", side_effect=requests.exceptions.ConnectionError("boom")), \
         patch("tasks.report_stil_done"), \
         patch("tasks.report_result") as mock_result, \
         patch("tasks.report_error") as mock_error, \
         patch("tasks.send_heartbeat"), \
         patch.object(run_job, "max_retries", 0):
        raised = False
        try:
            run_job.run(job_id="job-4", image_key="fake.png", model_version_id="v1", conformal_q=19.63)
        except requests.exceptions.ConnectionError:
            raised = True

    assert raised, "재시도 소진 후엔 원래 예외가 다시 던져져야 한다"
    mock_result.assert_not_called()
    mock_error.assert_called_once()
    assert "연결할 수 없습니다" in mock_error.call_args.args[1], "친절한 한국어 메시지가 아님"


if __name__ == "__main__":
    import sys
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    failed = 0
    for fn in fns:
        try:
            fn()
            print(f"  PASS  {fn.__name__}")
        except AssertionError as e:
            print(f"  FAIL  {fn.__name__}: {e}")
            failed += 1
        except Exception as e:  # noqa: BLE001 — 예상 못한 에러도 FAIL로 집계
            print(f"  FAIL  {fn.__name__}: {type(e).__name__}: {e}")
            failed += 1
    print(f"\n{len(fns) - failed}/{len(fns)} passed")
    sys.exit(1 if failed else 0)
