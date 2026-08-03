"""backend_api.py 검증 — 실제 서버 없이, requests.post를 가짜로 바꿔서
"어떤 URL/헤더/바디를 만드는지"와 "서버가 없어도 안 죽는지"를 확인한다.
"""
from unittest.mock import patch, MagicMock

from clients.backend_api import report_stil_done, report_result, report_error


def fake_ok_response():
    resp = MagicMock()
    resp.raise_for_status.return_value = None
    return resp


def test_report_stil_done_sends_correct_request():
    with patch("clients.backend_api.requests.post", return_value=fake_ok_response()) as mock_post:
        report_stil_done("job-1", {"stil_value": 50.0, "decision": "ABSTAIN"})

    args, kwargs = mock_post.call_args
    assert args[0].endswith("/analysis/jobs/job-1/callback/"), "URL이 계약과 다름"
    assert kwargs["headers"]["X-Internal-Token"] == "", "헤더 이름이 X-Internal-Token이어야 함"
    assert kwargs["json"]["status"] == "stil_done"
    assert kwargs["json"]["result"]["stil_value"] == 50.0


def test_report_result_includes_medgemma_report():
    stats = {"stil_value": 32.49, "decision": "ABSTAIN"}
    report = {"summary": "가짜 요약", "generation_failed": False}

    with patch("clients.backend_api.requests.post", return_value=fake_ok_response()) as mock_post:
        report_result("job-2", stats, report)

    body = mock_post.call_args.kwargs["json"]
    assert body["status"] == "succeeded"
    assert body["result"]["stil_value"] == 32.49
    assert body["result"]["medgemma_report"] == report, "medgemma_report는 객체 그대로 들어가야 함"


def test_report_error_sends_status_failed():
    with patch("clients.backend_api.requests.post", return_value=fake_ok_response()) as mock_post:
        report_error("job-3", "세그멘테이션 실패")

    body = mock_post.call_args.kwargs["json"]
    assert body["status"] == "failed"
    assert body["error_message"] == "세그멘테이션 실패"


def test_connection_failure_does_not_crash():
    """서버가 아직 없어서 연결이 안 될 때 — 예외가 밖으로 새어나가면 안 된다.
    이게 새어나가면 워커가 통째로 멈춘다."""
    import requests as requests_module

    with patch("clients.backend_api.requests.post",
               side_effect=requests_module.exceptions.ConnectionError("서버 없음")):
        try:
            report_result("job-4", {"stil_value": 1.0}, {})
        except requests_module.exceptions.ConnectionError:
            assert False, "연결 실패가 밖으로 새어나감 — 워커가 죽을 수 있음"


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
