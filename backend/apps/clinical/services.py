from apps.common.gcs import generate_signed_url


def build_file_url(file_key: str) -> str:
    """처방전 파일 조회용 서명 URL(GET) 발급."""
    return generate_signed_url(file_key, method="GET")
