"""tasks.py(run_job) 검증 — 성공 경로와 실패 경로가 올바른 순서로
콜백을 보내는지 확인한다. Redis/Celery 자체는 필요 없다 —
run_job.run(...)으로 함수 알맹이만 직접 실행해서 본다.
"""
from unittest.mock import patch

from tasks import run_job


def test_success_path_calls_stil_done_then_result():
    with patch("tasks.report_stil_done") as mock_stil_done, \
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


def test_stil_done_is_reported_before_medgemma_report_generated():
    """중간 보고(stil_done)에는 medgemma_report가 아직 없어야 한다.
    이게 섞이면 '계산 끝나자마자 먼저 알린다'는 의도가 깨진 것이다."""
    with patch("tasks.report_stil_done") as mock_stil_done, \
         patch("tasks.report_result"), \
         patch("tasks.report_error"), \
         patch("tasks.send_heartbeat"):
        run_job.run(job_id="job-2", image_key="fake.png", model_version_id="v1", conformal_q=19.63)

    stil_done_stats = mock_stil_done.call_args.args[1]
    assert "medgemma_report" not in stil_done_stats, "중간 보고에 리포트가 이미 섞여 들어감"


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
    print(f"\n{len(fns) - failed}/{len(fns)} passed")
    sys.exit(1 if failed else 0)
