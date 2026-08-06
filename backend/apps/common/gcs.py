"""GCS 서명 URL 공통 헬퍼 — 업로드(PUT)/조회(GET) 둘 다 여기서 만든다.

Cloud Run은 서비스 계정 키 파일이 없으므로(조직 정책으로 키 발급 자체가
막혀있음 — worker/INTERFACE.md 2절과 동일한 이유) IAM SignBlob API로
서명한다. 이 서비스 계정 자신에게 roles/iam.serviceAccountTokenCreator
권한이 있어야 동작한다.
"""

from datetime import timedelta

from django.conf import settings

# 프로세스(Cloud Run 인스턴스) 수명 동안 재사용 — 최일운/윤수용 리포트로
# 발견(2026-08-05): 매 서명 URL마다 OAuth 토큰 갱신 + IAM 서명을 새로
# 하고 있어서, job이 여러 개인 배치 상세 응답이 외부 API 왕복을
# job 수만큼 곱절로(원본+마스크 각각) 발생시켜 느렸다. base
# credentials/서명용 credentials/storage Client를 캐싱해서 실제
# GCS IAM signBlob 호출 1번(URL당 불가피)만 남긴다.
_cache: dict = {}


def _get_signing_context():
    base_credentials = _cache.get("base_credentials")
    if base_credentials is not None and base_credentials.valid:
        return _cache["signing_credentials"], base_credentials, _cache["client"]

    import google.auth  # noqa: PLC0415
    from google.auth import iam  # noqa: PLC0415
    from google.auth.transport import requests as gauth_requests  # noqa: PLC0415
    from google.cloud import storage  # noqa: PLC0415
    from google.oauth2 import service_account  # noqa: PLC0415

    base_credentials, _ = google.auth.default()
    auth_request = gauth_requests.Request()
    base_credentials.refresh(auth_request)

    signer = iam.Signer(auth_request, base_credentials, base_credentials.service_account_email)
    signing_credentials = service_account.Credentials(
        signer,
        base_credentials.service_account_email,
        token_uri="https://oauth2.googleapis.com/token",
    )
    client = storage.Client(credentials=base_credentials)

    _cache["base_credentials"] = base_credentials
    _cache["signing_credentials"] = signing_credentials
    _cache["client"] = client
    return signing_credentials, base_credentials, client


def generate_signed_url(
    storage_key: str,
    *,
    method: str = "GET",
    content_type: str | None = None,
    expires_minutes: int = 15,
) -> str:
    if not settings.GCS_BUCKET:
        return f"https://mock-signed-url.local/{method.lower()}/{storage_key}"

    signing_credentials, _base_credentials, client = _get_signing_context()
    blob = client.bucket(settings.GCS_BUCKET).blob(storage_key)

    kwargs = {
        "version": "v4",
        "expiration": timedelta(minutes=expires_minutes),
        "method": method,
        "credentials": signing_credentials,
    }
    if content_type:
        kwargs["content_type"] = content_type

    return blob.generate_signed_url(**kwargs)
