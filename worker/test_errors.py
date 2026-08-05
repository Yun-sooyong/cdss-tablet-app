"""errors.py 검증 — 예외 타입별로 올바른 한국어 문구로 바뀌는지 확인."""
import requests

from pipeline.errors import TRANSIENT_EXCEPTIONS, friendly_error


def test_connection_error_message():
    exc = requests.exceptions.ConnectionError("...")
    msg = friendly_error(exc)
    assert "연결할 수 없습니다" in msg


def test_timeout_message():
    exc = requests.exceptions.Timeout("...")
    msg = friendly_error(exc)
    assert "시간 내에" in msg


def test_http_422_message():
    resp = requests.Response()
    resp.status_code = 422
    exc = requests.exceptions.HTTPError(response=resp)
    msg = friendly_error(exc)
    assert "요청 데이터에 문제" in msg


def test_http_500_message():
    resp = requests.Response()
    resp.status_code = 503
    exc = requests.exceptions.HTTPError(response=resp)
    msg = friendly_error(exc)
    assert "내부에서 오류" in msg


def test_value_error_passes_through_unchanged():
    """til_conformal.py/mosec.py가 이미 한국어로 명확하게 써둔 메시지는
    그대로 노출해야 한다 — 여기서 다시 바꾸면 원인 파악이 더 어려워진다."""
    exc = ValueError("conformal_q가 없습니다 — 이 모델은 아직 보정되지 않았을 수 있습니다")
    msg = friendly_error(exc)
    assert msg == str(exc)


def test_connection_error_and_timeout_are_transient():
    assert requests.exceptions.ConnectionError in TRANSIENT_EXCEPTIONS
    assert requests.exceptions.Timeout in TRANSIENT_EXCEPTIONS


def test_value_error_is_not_transient():
    """ValueError(잘못된 입력값)는 재시도해도 똑같이 실패하므로
    TRANSIENT_EXCEPTIONS에 들어있으면 안 된다 — 무한 재시도 낭비 방지."""
    assert not issubclass(ValueError, TRANSIENT_EXCEPTIONS)


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
