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
               side_effect=requests_module.exceptions.ConnectionError("서버 없음")), \
         patch("clients.backend_api.time.sleep"):  # 재시도 대기시간은 건너뛴다
        try:
            report_result("job-4", {"stil_value": 1.0}, {})
        except requests_module.exceptions.ConnectionError:
            assert False, "연결 실패가 밖으로 새어나감 — 워커가 죽을 수 있음"


def test_transient_failure_is_retried_until_success():
    """2026-08-05: 첫 두 번 연결이 끊겨도 세 번째에 성공하면 결과가 전달돼야 한다.
    이게 없으면 몇 분치 GPU 작업 결과가 순간적인 네트워크 흔들림 하나로 증발한다."""
    import requests as requests_module

    attempts = [
        requests_module.exceptions.ConnectionError("일시적 끊김"),
        requests_module.exceptions.Timeout("느림"),
        fake_ok_response(),
    ]

    def flaky_post(*args, **kwargs):
        outcome = attempts.pop(0)
        if isinstance(outcome, Exception):
            raise outcome
        return outcome

    with patch("clients.backend_api.requests.post", side_effect=flaky_post) as mock_post, \
         patch("clients.backend_api.time.sleep"):
        report_result("job-5", {"stil_value": 12.3}, {"summary": "요약"})

    assert mock_post.call_count == 3, f"3번까지 시도해야 하는데 {mock_post.call_count}번만 시도함"
    assert not attempts, "마지막 성공 응답을 안 썼음"


def test_client_error_is_not_retried():
    """토큰이 틀렸거나(401) 주소가 없으면(404) 몇 번을 다시 보내도 결과가 같다.
    괜히 재시도하면 실패를 늦게 알게 될 뿐이라 한 번만 시도하고 포기해야 한다."""
    import requests as requests_module

    resp = MagicMock()
    resp.status_code = 401
    err = requests_module.exceptions.HTTPError("인증 실패", response=resp)
    resp.raise_for_status.side_effect = err

    with patch("clients.backend_api.requests.post", return_value=resp) as mock_post, \
         patch("clients.backend_api.time.sleep"):
        report_error("job-6", "실패함")

    assert mock_post.call_count == 1, f"4xx는 재시도하면 안 되는데 {mock_post.call_count}번 시도함"


def test_server_error_is_retried():
    """5xx는 백엔드가 잠깐 흔들리는 것일 수 있으므로 재시도 대상이다."""
    import requests as requests_module

    resp = MagicMock()
    resp.status_code = 503
    err = requests_module.exceptions.HTTPError("서버 불안정", response=resp)
    resp.raise_for_status.side_effect = err

    with patch("clients.backend_api.requests.post", return_value=resp) as mock_post, \
         patch("clients.backend_api.time.sleep"):
        report_result("job-7", {"stil_value": 5.0}, {})

    assert mock_post.call_count == 3, f"5xx는 3번까지 시도해야 하는데 {mock_post.call_count}번만 시도함"


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
