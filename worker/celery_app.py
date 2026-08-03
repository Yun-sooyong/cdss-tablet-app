"""Celery 앱 초기화 — 우체부(Celery)가 어느 우체통(Redis)을 볼지 정한다.

BACKEND_API_BASE, MOSEC_URL 같은 나머지 설정은 각 클라이언트 파일에서 따로 읽는다.
여기서는 "우체통이 어디에 있는지"만 다룬다.
"""
import os

from celery import Celery
from dotenv import load_dotenv

# .env 파일 내용을 실제 환경변수로 등록한다. 이걸 안 하면 .env 파일에
# 뭘 적어도 os.environ.get()이 그 값을 못 보고 계속 기본값만 쓴다.
# celery_app.py가 제일 먼저 import되는 진입점이라 여기서 한 번만 불러도
# 이후 tasks.py, clients/* 전부 os.environ으로 값을 읽을 수 있다.
load_dotenv()

BROKER_URL = os.environ.get("CELERY_BROKER_URL", "redis://localhost:6379/0")

# include=["tasks"] — 이 앱이 시작될 때 tasks.py를 같이 불러와서
# 그 안의 @app.task 함수들을 우체부에게 등록시킨다.
app = Celery("worker", broker=BROKER_URL, include=["tasks"])

# ⚠️ 백엔드가 analysis.run_job을 queue="gpu"로 보낸다(정다희 확인, 2026-08-03).
# 이 줄이 없으면 우체부가 기본 큐("celery")만 듣고 있어서
# "gpu" 큐에 쌓인 쪽지를 영원히 못 본다 — 에러도 안 나고 그냥 쌓이기만 한다.
app.conf.task_default_queue = "gpu"
