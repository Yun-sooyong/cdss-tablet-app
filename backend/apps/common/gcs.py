"""GCS 서명 URL 공통 헬퍼 — 업로드(PUT)/조회(GET) 둘 다 여기서 만든다.

Cloud Run은 서비스 계정 키 파일이 없으므로(조직 정책으로 키 발급 자체가
막혀있음 — worker/INTERFACE.md 2절과 동일한 이유) IAM SignBlob API로
서명한다. 이 서비스 계정 자신에게 roles/iam.serviceAccountTokenCreator
권한이 있어야 동작한다.
"""

from datetime import timedelta

from django.conf import settings


def generate_signed_url(
    storage_key: str,
    *,
    method: str = "GET",
    content_type: str | None = None,
    expires_minutes: int = 15,
) -> str:
    if not settings.GCS_BUCKET:
        return f"https://mock-signed-url.local/{method.lower()}/{storage_key}"

    import google.auth  # noqa: PLC0415
    from google.auth import iam  # noqa: PLC0415
    from google.auth.transport import requests as gauth_requests  # noqa: PLC0415
    from google.cloud import storage  # noqa: PLC0415
    from google.oauth2 import service_account  # noqa: PLC0415

    credentials, _ = google.auth.default()
    auth_request = gauth_requests.Request()
    credentials.refresh(auth_request)

    signer = iam.Signer(auth_request, credentials, credentials.service_account_email)
    signing_credentials = service_account.Credentials(
        signer,
        credentials.service_account_email,
        token_uri="https://oauth2.googleapis.com/token",
    )

    client = storage.Client(credentials=credentials)
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
