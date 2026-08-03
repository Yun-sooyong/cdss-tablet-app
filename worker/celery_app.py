"""Celery 앱 초기화 — 우체부(Celery)가 어느 우체통(Redis)을 볼지 정한다.

BACKEND_API_BASE, MOSEC_URL 같은 나머지 설정은 각 클라이언트 파일에서 따로 읽는다.
여기서는 "우체통이 어디에 있는지"만 다룬다.
"""
import os

from celery import Celery

BROKER_URL = os.environ.get("CELERY_BROKER_URL", "redis://localhost:6379/0")

# include=["tasks"] — 이 앱이 시작될 때 tasks.py를 같이 불러와서
# 그 안의 @app.task 함수들을 우체부에게 등록시킨다.
app = Celery("worker", broker=BROKER_URL, include=["tasks"])
