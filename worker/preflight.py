"""시연 직전 상태 점검 — 우체통·현미경·접수처가 다 살아있는지 10초 만에 확인한다.

    python preflight.py

전부 초록불이면 바로 시연해도 되고, 빨간불이 뜨면 그 줄에 적힌 곳부터 보면 된다.
"진짜 작업을 한 번 돌려보고 안 되면 원인 찾기" 대신, 어디가 끊겼는지를 먼저
알려주는 게 목적이다.

⚠️ 이 스크립트는 아무것도 바꾸지 않는다 — 읽기·연결 확인만 한다.
   Mosec에는 일부러 잘못된 요청을 보내서 "422로 거절당하는지"를 본다.
   거절당한다는 건 곧 서버가 살아서 요청을 제대로 검사하고 있다는 뜻이다.
"""
import os
import sys

import msgpack
import requests
from dotenv import load_dotenv

load_dotenv()

MOSEC_URL = os.environ.get("MOSEC_URL", "http://localhost:8000")
BACKEND_API_BASE = os.environ.get("BACKEND_API_BASE", "http://localhost:8000/api/v1")
INTERNAL_API_TOKEN = os.environ.get("INTERNAL_API_TOKEN", "")
BROKER_URL = os.environ.get("CELERY_BROKER_URL", "redis://localhost:6379/0")
GCS_BUCKET = os.environ.get("GCS_BUCKET", "")

# 존재하지 않는 job_id — 접수처가 살아있는지만 보려는 것이라 실제 데이터를
# 건드리지 않도록 일부러 아무것도 매칭되지 않는 값을 쓴다.
FAKE_JOB_ID = "00000000-0000-0000-0000-000000000000"

OK, WARN, FAIL = "OK", "WARN", "FAIL"
_MARK = {OK: "  [OK]  ", WARN: "  [주의] ", FAIL: "  [실패] "}

results = []


def record(status: str, name: str, detail: str, hint: str = "") -> None:
    results.append((status, name, detail, hint))
    print(f"{_MARK[status]}{name} — {detail}")
    if hint and status != OK:
        print(f"          ↳ {hint}")


def check_env():
    """제일 흔한 사고: .env를 안 읽었거나 값이 비어있는 경우."""
    missing = [k for k, v in {
        "MOSEC_URL": MOSEC_URL,
        "BACKEND_API_BASE": BACKEND_API_BASE,
        "CELERY_BROKER_URL": BROKER_URL,
        "GCS_BUCKET": GCS_BUCKET,
    }.items() if not v]
    if missing:
        record(FAIL, "환경변수", f"비어있음: {', '.join(missing)}",
               "worker/.env 파일이 있는지, 이 폴더에서 실행했는지 확인")
        return
    if not INTERNAL_API_TOKEN:
        record(WARN, "환경변수", "INTERNAL_API_TOKEN이 비어있음",
               "콜백이 401로 거절될 수 있다 — 백엔드와 같은 값인지 확인")
        return
    record(OK, "환경변수", f"MOSEC={MOSEC_URL}, BUCKET={GCS_BUCKET}")


def check_redis():
    """우체통(Redis)이 열려있는지 + gpu 큐에 밀린 쪽지가 있는지."""
    try:
        from celery_app import app
        conn = app.connection()
        conn.ensure_connection(max_retries=0, timeout=3)
        try:
            depth = conn.default_channel.client.llen("gpu")
        except Exception:  # noqa: BLE001 — 큐 길이는 못 봐도 연결은 성공한 것
            depth = None
        conn.release()
    except Exception as exc:  # noqa: BLE001
        record(FAIL, "Redis(우체통)", f"연결 실패: {exc}",
               "Redis가 떠 있는지, CELERY_BROKER_URL 주소가 맞는지 확인")
        return

    if depth is None:
        record(OK, "Redis(우체통)", "연결됨")
    elif depth > 0:
        record(WARN, "Redis(우체통)", f"연결됨 — gpu 큐에 처리 안 된 쪽지 {depth}건이 밀려있음",
               "워커를 켜면 이것부터 처리한다. 시연 전에 비우려면 워커를 잠깐 돌려둘 것")
    else:
        record(OK, "Redis(우체통)", "연결됨 — gpu 큐 비어있음")


def _probe_mosec_route(route: str) -> "tuple[int | None, str]":
    """일부러 필수 필드를 뺀 요청을 보내 서버가 살아있는지 확인한다.
    422(검사에서 거절)면 서버·라우트·msgpack 처리가 전부 정상이라는 뜻이다."""
    try:
        resp = requests.post(
            f"{MOSEC_URL}{route}",
            data=msgpack.packb({"job_id": "preflight"}, use_bin_type=True),
            headers={"Content-Type": "application/msgpack"},
            timeout=10,
        )
        return resp.status_code, ""
    except requests.exceptions.RequestException as exc:
        return None, str(exc)


def check_mosec_inference():
    code, err = _probe_mosec_route("/inference")
    if code is None:
        record(FAIL, "Mosec /inference(현미경)", f"연결 안 됨: {err}",
               "GPU 워크스테이션에서 start_mosec.sh가 돌고 있는지, SSH 터널이 살아있는지 확인")
    elif code == 422:
        record(OK, "Mosec /inference(현미경)", "살아있음 (필수 필드 검사 정상 작동)")
    else:
        record(WARN, "Mosec /inference(현미경)", f"응답은 왔지만 예상 밖의 코드: {code}",
               "422가 정상이다. 서버 로그를 확인할 것")


def check_mosec_medgemma():
    code, err = _probe_mosec_route("/medgemma")
    if code is None:
        record(FAIL, "Mosec /medgemma(판독의)", f"연결 안 됨: {err}",
               "start_mosec.sh에 ENABLE_MEDGEMMA=1이 있는지 확인")
    elif code == 404:
        record(FAIL, "Mosec /medgemma(판독의)", "라우트가 없음 (404)",
               "MedGemma 워커가 안 떴다 — ENABLE_MEDGEMMA=1로 서버를 다시 시작할 것")
    elif code in (422, 400):
        record(OK, "Mosec /medgemma(판독의)", "살아있음")
    else:
        record(WARN, "Mosec /medgemma(판독의)", f"예상 밖의 코드: {code}", "서버 로그를 확인할 것")


def check_backend():
    """접수처(Django)가 콜백을 받을 수 있는 상태인지.
    존재하지 않는 job_id로 보내므로 실제 데이터는 건드리지 않는다."""
    url = f"{BACKEND_API_BASE}/analysis/jobs/{FAKE_JOB_ID}/callback/"
    try:
        resp = requests.post(
            url,
            json={"status": "failed", "result": {}, "error_message": "preflight check"},
            headers={"X-Internal-Token": INTERNAL_API_TOKEN},
            timeout=10,
        )
    except requests.exceptions.RequestException as exc:
        record(FAIL, "Django 콜백(접수처)", f"연결 안 됨: {exc}",
               "BACKEND_API_BASE 주소가 맞는지, Cloud Run 서비스가 살아있는지 확인")
        return

    if resp.status_code in (401, 403):
        record(FAIL, "Django 콜백(접수처)", f"인증 거절({resp.status_code})",
               "INTERNAL_API_TOKEN이 백엔드 쪽 값과 다르다 — 다희님과 대조할 것")
    elif resp.status_code == 404:
        record(OK, "Django 콜백(접수처)", "살아있음 (없는 job이라 404 — 정상)")
    elif resp.status_code < 500:
        record(OK, "Django 콜백(접수처)", f"살아있음 (코드 {resp.status_code})")
    else:
        record(WARN, "Django 콜백(접수처)", f"서버 오류({resp.status_code})",
               "백엔드가 떠 있긴 하지만 에러 상태다 — 다희님께 확인 요청")


def check_gcs():
    """워커 쪽 GCS 읽기 권한 — 지금 구조에선 Mosec이 대신 읽으므로 없어도 된다."""
    if not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        record(OK, "GCS(워커 쪽)", "자격증명 미설정 — 건너뜀 (Mosec이 대신 읽으므로 정상)")
        return
    try:
        from clients.gcs import _get_client
        list(_get_client().bucket(GCS_BUCKET).list_blobs(max_results=1))
        record(OK, "GCS(워커 쪽)", f"{GCS_BUCKET} 읽기 가능")
    except Exception as exc:  # noqa: BLE001
        record(WARN, "GCS(워커 쪽)", f"읽기 실패: {exc}",
               "지금 구조에선 Mosec이 GCS를 읽으므로 시연에는 지장 없다")


def main():
    print("\n시연 전 상태 점검\n" + "=" * 58)
    check_env()
    check_redis()
    check_mosec_inference()
    check_mosec_medgemma()
    check_backend()
    check_gcs()

    fails = [r for r in results if r[0] == FAIL]
    warns = [r for r in results if r[0] == WARN]
    print("=" * 58)
    if fails:
        print(f"\n❌ 실패 {len(fails)}건 — 이대로 시연하면 안 된다.")
        for _, name, _, hint in fails:
            print(f"   · {name}: {hint}")
    elif warns:
        print(f"\n⚠️  주의 {len(warns)}건 — 돌아가긴 하지만 확인해두는 게 좋다.")
    else:
        print("\n✅ 전부 정상 — 시연 준비 완료.")
    print()
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
