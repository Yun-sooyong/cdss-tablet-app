import os

from .base import *  # noqa: F401,F403

SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
DEBUG = False
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "").split(",")

# TODO: Cloud SQL 접속 정보로 채울 것 (DATABASE_URL)
DATABASES = {}
