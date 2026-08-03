"""테스트용 — Django가 하는 일을 흉내내서 우체통(Redis)에 쪽지 하나를 넣어본다.

queue="gpu"까지 실제 백엔드 코드(정다희 확인)와 똑같이 맞춰서, 큐 이름이
안 맞아 쪽지가 안 집히는 문제를 로컬에서도 재현/검증할 수 있게 한다.

실행: python send_test_task.py
(celery_app.py 우체부가 다른 창에서 켜져 있어야 결과를 가져간다)
"""
from celery_app import app

result = app.send_task(
    "analysis.run_job",
    kwargs={
        "job_id": "test-1",
        "image_key": "fake/image.png",
        "model_version_id": "v1",
        "conformal_q": 19.63,
    },
    queue="gpu",
)

print(f"쪽지 보냄. id = {result.id}")
print("우체부 창(celery worker)에 새 로그가 떴는지 확인하세요.")
