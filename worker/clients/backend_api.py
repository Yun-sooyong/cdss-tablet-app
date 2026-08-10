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
import time

import requests

BACKEND_API_BASE = os.environ.get("BACKEND_API_BASE", "http://localhost:8000/api/v1")
INTERNAL_API_TOKEN = os.environ.get("INTERNAL_API_TOKEN", "")

# 콜백 전송 재시도 설정 (2026-08-05).
# 세그멘테이션+MedGemma까지 몇 분 걸려 만든 결과를, 전송하는 그 순간의
# 일시적인 네트워크 흔들림 하나로 통째로 날리지 않기 위한 안전장치다.
CALLBACK_MAX_ATTEMPTS = 3
CALLBACK_BACKOFF_SEC = 2  # 2초 → 4초 순으로 늘어난다


def _callback(job_id: str, status: str, result: dict = None, error_message: str = "") -> None:
    """접수처에 결과를 보고한다. 전송 실패 시 최대 3번까지 다시 시도한다.

    ⚠️ 재시도하는 건 '전송'뿐이고 GPU 계산을 다시 하는 게 아니다 — 이미 손에
       들고 있는 결과를 다시 부치기만 하는 거라 비용이 거의 없다.
    ⚠️ 4xx(주소·토큰·형식이 틀림)는 몇 번을 다시 보내도 똑같이 거절당하므로
       재시도하지 않고 바로 포기한다. 5xx·연결 실패·타임아웃만 재시도 대상.
    """
    url = f"{BACKEND_API_BASE}/analysis/jobs/{job_id}/callback/"
    headers = {"X-Internal-Token": INTERNAL_API_TOKEN}
    body = {"status": status, "result": result or {}, "error_message": error_message}

    for attempt in range(1, CALLBACK_MAX_ATTEMPTS + 1):
        try:
            resp = requests.post(url, json=body, headers=headers, timeout=10)
            resp.raise_for_status()
            if attempt > 1:
                print(f"[backend_api] 콜백 성공 — status={status} ({attempt}번째 시도에 성공)")
            else:
                print(f"[backend_api] 콜백 성공 — status={status}")
            return
        except requests.exceptions.HTTPError as exc:
            code = exc.response.status_code if exc.response is not None else 0
            if 400 <= code < 500:
                # 다시 보내도 결과가 같은 실패 — 주소/토큰/본문 형식을 봐야 한다.
                print(f"[backend_api] ⚠️ 콜백 거절({code}, status={status}) — 재시도해도 같으므로 중단: {exc}")
                return
            last_exc = exc
        except requests.exceptions.RequestException as exc:
            last_exc = exc

        if attempt < CALLBACK_MAX_ATTEMPTS:
            wait = CALLBACK_BACKOFF_SEC * attempt  # 2초, 4초
            print(f"[backend_api] ⚠️ 콜백 실패({attempt}/{CALLBACK_MAX_ATTEMPTS}, {wait}초 후 재시도, "
                  f"status={status}): {last_exc}")
            time.sleep(wait)

    # 여기까지 왔으면 세 번 다 실패 — 워커 전체가 멈추면 안 되므로 예외를
    # 밖으로 던지지는 않되, 결과가 유실됐다는 사실이 로그에서 눈에 띄게 남긴다.
    print(f"[backend_api] ❌ 콜백 최종 실패 — status={status}, job_id={job_id}. "
          f"이 작업의 결과는 접수처에 저장되지 않았다: {last_exc}")


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
