from .base import *  # noqa: F401,F403

SECRET_KEY = "dev-only-not-for-prod"
DEBUG = True
ALLOWED_HOSTS = ["*"]

# 팀원이 Postgres 설치 없이 바로 실행할 수 있도록 sqlite로 시작한다.
# Postgres 전환 시 DATABASE_URL 기반으로 교체.
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",  # noqa: F405
    }
}
