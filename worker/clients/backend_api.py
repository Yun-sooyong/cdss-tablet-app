"""접수처(Django)에 결과·실패·생존 신고를 보내는 클라이언트.

⚠️ Django 쪽에 이 엔드포인트들이 아직 실제로 만들어지지 않았다(정다희님 작업 예정).
   그래서 지금은 연결이 안 되는 게 정상이다. 연결 실패해도 워커가 죽지 않도록
   방어해뒀다 — 나중에 진짜 서버가 뜨면 이 파일은 고칠 필요 없이 그대로 동작한다.
"""
import os

import requests

BACKEND_API_BASE = os.environ.get("BACKEND_API_BASE", "http://localhost:8000/api/v1")
INTERNAL_API_TOKEN = os.environ.get("INTERNAL_API_TOKEN", "")


def _call(method: str, path: str, json_body: dict) -> None:
    url = f"{BACKEND_API_BASE}{path}"
    headers = {"Authorization": f"Bearer {INTERNAL_API_TOKEN}"}
    try:
        resp = requests.request(method, url, json=json_body, headers=headers, timeout=5)
        resp.raise_for_status()
        print(f"[backend_api] {method} {path} 성공")
    except requests.exceptions.RequestException as exc:
        # 접수처가 아직 없거나 응답이 없는 상황 — 이것 때문에 워커 전체가
        # 멈추면 안 되므로 여기서 예외를 막고 로그만 남긴다.
        print(f"[backend_api] ⚠️ {method} {path} 실패(서버 미구현/연결 불가): {exc}")


def report_result(job_id: str, stats: dict, report: dict) -> None:
    """정상 완료 — 결과를 접수처에 저장 요청."""
    _call("PATCH", f"/internal/jobs/{job_id}", {
        "status": "done",
        "stil_value": stats["stil_value"],
        "conformal_prediction_value": stats,
        "medgemma_report": report,
    })


def report_error(job_id: str, error_message: str) -> None:
    """실패 — 에러 전용 엔드포인트에 보고."""
    _call("POST", f"/internal/jobs/{job_id}/error", {
        "error_message": error_message,
    })


def send_heartbeat(worker_name: str) -> None:
    """생존 신고 — 이 워커가 살아있다고 주기적으로 알림."""
    _call("POST", "/internal/workers/heartbeat", {
        "worker_name": worker_name,
    })
