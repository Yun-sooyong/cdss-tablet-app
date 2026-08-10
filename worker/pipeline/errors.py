"""실패 사유를 사람이 읽을 수 있는 한국어 문구로 바꾼다.

Django의 error_message 필드에 그대로 노출되는 값이라, 파이썬 예외 원문
(예: "HTTPConnectionPool(host='localhost'...)")보다는 병리의/사용자가
이해할 수 있는 문장이어야 한다.
"""
import requests

# 재시도할 가치가 있는 예외 — 네트워크가 잠깐 끊기거나 서버가 순간적으로
# 응답 못한 경우. 잘못된 입력값(ValueError 등)은 다시 시도해도 똑같이
# 실패하므로 여기 넣지 않는다 — 무한히 똑같은 실패를 반복하며 시간만
# 낭비하게 된다.
TRANSIENT_EXCEPTIONS = (
    requests.exceptions.ConnectionError,
    requests.exceptions.Timeout,
)


def friendly_error(exc: Exception) -> str:
    """예외를 Django error_message용 한국어 문장으로 변환."""
    if isinstance(exc, requests.exceptions.ConnectionError):
        return "Mosec 서버에 연결할 수 없습니다. GPU 서버 또는 SSH 터널 상태를 확인해주세요."
    if isinstance(exc, requests.exceptions.Timeout):
        return "Mosec 서버 응답이 시간 내에 오지 않았습니다. 서버가 처리 중이거나 응답이 지연되고 있을 수 있습니다."
    if isinstance(exc, requests.exceptions.HTTPError):
        status = exc.response.status_code if exc.response is not None else None
        if status == 422:
            return "요청 데이터에 문제가 있습니다 (이미지 경로 또는 모델 이름을 확인해주세요)."
        if status == 404:
            return "요청한 리소스를 찾을 수 없습니다 (이미지 경로를 확인해주세요)."
        if status is not None and status >= 500:
            return "Mosec 서버 내부에서 오류가 발생했습니다."
        return f"Mosec 서버가 요청을 거부했습니다 (상태 코드 {status})."
    if isinstance(exc, ValueError):
        # til_conformal.py, mosec.py에서 이미 한국어로 명확하게 작성된
        # 메시지들 — 그대로 노출해도 된다.
        return str(exc)
    return f"처리 중 오류가 발생했습니다: {exc}"
