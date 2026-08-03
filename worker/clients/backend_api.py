"""접수처(Django)에 결과·실패를 보고하는 클라이언트.

계약 (정다희 확인, 2026-08-03):
    POST /api/v1/analysis/jobs/{job_id}/callback/
    Header: X-Internal-Token: <INTERNAL_API_TOKEN>
    Body:   {"status": "stil_done" | "succeeded" | "failed", "result": {...}, "error_message": ""}

⚠️ 성공/실패가 엔드포인트가 아니라 status 값으로 구분된다 — 예전엔 실패 전용
   엔드포인트가 따로 있는 걸로 짰었는데, 실제 구현은 하나로 합쳐져 있다.
⚠️ 헤더 이름이 X-Internal-Token이다. Authorization: Bearer 형식이 아니다.
⚠️ INTERNAL_API_TOKEN 값은 backend/.env와 worker/.env에 똑같이 들어가야 한다.
   .env는 git에 안 올라가므로(.gitignore) 슬랙 DM 등 별도 채널로 전달받을 것.

⚠️ 콜백은 케이스당 최대 2번 나간다 (2026-08-03, 일운님 프론트 질문 계기로 확정):
   1) stil_done — sTIL·Conformal 끝나자마자, MedGemma 시작 전. medgemma_report 없음.
   2) succeeded — MedGemma까지 끝난 뒤 최종. medgemma_report 포함.
   실패는 어느 단계에서 나든 failed 한 번으로 끝난다.
   이전 프로젝트(worker_dev)의 실제 동작을 그대로 이어받은 것 — 계산은 금방 끝나도
   MedGemma 생성은 더 오래 걸려서, sTIL 수치만이라도 먼저 보여주려는 의도다.
"""
import os

import requests

BACKEND_API_BASE = os.environ.get("BACKEND_API_BASE", "http://localhost:8000/api/v1")
INTERNAL_API_TOKEN = os.environ.get("INTERNAL_API_TOKEN", "")


def _callback(job_id: str, status: str, result: dict = None, error_message: str = "") -> None:
    url = f"{BACKEND_API_BASE}/analysis/jobs/{job_id}/callback/"
    headers = {"X-Internal-Token": INTERNAL_API_TOKEN}
    body = {"status": status, "result": result or {}, "error_message": error_message}
    try:
        resp = requests.post(url, json=body, headers=headers, timeout=5)
        resp.raise_for_status()
        print(f"[backend_api] 콜백 성공 — status={status}")
    except requests.exceptions.RequestException as exc:
        # 접수처가 아직 없거나 응답이 없는 상황 — 이것 때문에 워커 전체가
        # 멈추면 안 되므로 여기서 예외를 막고 로그만 남긴다.
        print(f"[backend_api] ⚠️ 콜백 실패(서버 미구현/연결 불가, status={status}): {exc}")


def report_stil_done(job_id: str, stats: dict) -> None:
    """중간 보고 — sTIL·Conformal 계산 끝, MedGemma 리포트는 아직.
    프론트가 이 상태에서 '리포트 작성중' 같은 걸 보여줄 수 있게 먼저 알린다."""
    _callback(job_id, status="stil_done", result=stats)


def report_result(job_id: str, stats: dict, report: dict) -> None:
    """최종 완료 — MedGemma 리포트까지 포함해서 결과를 접수처에 저장 요청."""
    _callback(job_id, status="succeeded", result={**stats, "medgemma_report": report})


def report_error(job_id: str, error_message: str) -> None:
    """실패 — 같은 콜백에 status=failed로 보고."""
    _callback(job_id, status="failed", error_message=error_message)


def send_heartbeat(worker_name: str) -> None:
    """생존 신고 — ⚠️ 백엔드에 아직 이 엔드포인트가 없다(2단계 이후 항목).
    지금은 호출해도 그냥 조용히 실패한다. 나중에 엔드포인트 생기면 주소만 채우면 됨."""
    url = f"{BACKEND_API_BASE}/internal/workers/heartbeat"
    try:
        requests.post(url, json={"worker_name": worker_name},
                       headers={"X-Internal-Token": INTERNAL_API_TOKEN}, timeout=5)
    except requests.exceptions.RequestException:
        pass  # 아직 없는 엔드포인트라 실패가 기본값 — 로그로 스팸 남기지 않음
