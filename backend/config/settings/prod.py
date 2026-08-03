import os

import dj_database_url

from .base import *  # noqa: F401,F403

SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
DEBUG = False
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "").split(",")

# Cloud Run -> Cloud SQL은 유닉스 소켓(Auth Proxy 내장 방식)으로 붙는다.
# --add-cloudsql-instances로 지정한 인스턴스가 /cloudsql/<연결이름>에 마운트된다.
# DATABASE_URL 형식:
#   postgresql://USER:PASSWORD@/DBNAME?host=/cloudsql/<프로젝트ID>:asia-northeast3:medical-ai-db
# (@와 / 사이에 호스트가 비어있는 게 정상 — 실제 호스트는 host 쿼리파라미터로 전달됨)
DATABASES = {
    "default": dj_database_url.parse(
        os.environ["DATABASE_URL"], conn_max_age=600, ssl_require=False
    )
}

# 정적 파일(admin, drf-spectacular 등)을 별도 서버 없이 컨테이너 안에서 서빙.
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    *MIDDLEWARE[1:],  # noqa: F405 — base.py의 SecurityMiddleware 다음부터 이어붙임
]
STORAGES = {
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}

SECURE_SSL_REDIRECT = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
