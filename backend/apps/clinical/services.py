def build_file_url(file_key: str) -> str:
    """처방전 파일 서명 URL 발급.

    TODO: 실제 GCS 서명 URL로 교체할 것 (apps.analysis.services.build_upload_url
    과 동일한 이유로 아직 mock).
    """
    return f"https://mock-signed-url.local/{file_key}"
