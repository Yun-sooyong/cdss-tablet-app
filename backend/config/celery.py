"""backend 전용 Celery 앱 — 작업을 큐에 등록(send_task)만 한다.

워커(worker/celery_app.py)와는 코드를 공유하지 않는다. 태스크 이름
("analysis.run_job")과 payload 키만으로 연결된다 (worker/INTERFACE.md).
backend는 이 큐를 소비하지 않으므로 @app.task 등록이나 워커 실행 로직은
여기 없다.
"""

from django.conf import settings

from celery import Celery

app = Celery("medical_ai_backend", broker=settings.CELERY_BROKER_URL)
