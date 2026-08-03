import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # third-party
    "rest_framework",
    "drf_spectacular",
    "encrypted_model_fields",
    # local apps
    "apps.common",
    "apps.accounts",
    "apps.patients",
    "apps.staff",
    "apps.clinical",
    "apps.analysis",
    "apps.chat",
]

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}

SPECTACULAR_SETTINGS = {
    "TITLE": "medical-ai-platform API",
    "DESCRIPTION": "CDSS 백엔드 API. 세로 슬라이스(로그인~job 조회) 우선 구현.",
    "VERSION": "0.1.0",
    "SERVE_INCLUDE_SCHEMA": False,
}

# 로컬/데모 환경에서 워커(Celery+GPU) 없이 세로 슬라이스를 끝까지 돌리기 위한 플래그.
# true면 job 생성 시 실제 큐 대신 즉시 mock 결과로 콜백을 흉내낸다.
USE_MOCK_INFERENCE = os.environ.get("USE_MOCK_INFERENCE", "true").lower() == "true"

# worker -> backend 콜백 인증용. worker/.env의 값과 반드시 동일해야 한다 (README 6절).
INTERNAL_API_TOKEN = os.environ.get("INTERNAL_API_TOKEN", "")

# backend는 워커에게 작업을 등록(send_task)만 한다 — 큐를 소비하지 않는다 (config/celery.py).
CELERY_BROKER_URL = os.environ.get("CELERY_BROKER_URL", "")

# 최초 migrate 이전에 반드시 설정되어 있어야 한다. 자세한 내용은 README 참조.
AUTH_USER_MODEL = "accounts.User"

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ]
        },
    }
]

LANGUAGE_CODE = "ko-kr"
TIME_ZONE = "Asia/Seoul"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
