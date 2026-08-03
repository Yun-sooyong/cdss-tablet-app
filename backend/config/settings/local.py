from .base import *  # noqa: F401,F403

SECRET_KEY = "dev-only-not-for-prod"
DEBUG = True
ALLOWED_HOSTS = ["*"]

# 환자 식별정보 컬럼 암호화(django-encrypted-model-fields)용. 로컬 전용 고정값 —
# 운영에서는 반드시 환경변수/시크릿으로 별도 값을 써야 한다 (prod.py).
FIELD_ENCRYPTION_KEY = "MToZITXCrZqWZgXGxx6kFCfTMDpmas79qgQZPanXecw="

# 팀원이 Postgres 설치 없이 바로 실행할 수 있도록 sqlite로 시작한다.
# Postgres 전환 시 DATABASE_URL 기반으로 교체.
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",  # noqa: F405
    }
}
