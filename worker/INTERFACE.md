# backend ↔ worker 계약

backend(정다희)와 worker(박검모)는 코드를 공유하지 않는다. 태스크 이름과
payload 키, 콜백 엔드포인트만으로 연결된다. 이 문서가 계약의 기준이며,
변경 시 양쪽을 같은 PR에서 고친다.

확정일: 2026-08-03 (result 필드 상세는 2026-08-03 2차 수정)

---

## 1. 태스크: `analysis.run_job`

backend가 job 생성 시 아래 kwargs로 큐에 등록한다 (`queue="gpu"`).

```python
app.send_task(
    "analysis.run_job",
    kwargs={
        "job_id": str(job.id),
        "image_key": image.storage_key,     # GCS object key
        "model_version_id": str(mv.id),
        "conformal_q": mv.conformal_q,
    },
    queue="gpu",
)
```

payload에 환자 정보는 없다. 워커는 `job_id`만 알고, 환자 연결은 결과 조회 시
backend가 조인한다.

## 2. 이미지 다운로드

워커가 GCS에서 `image_key`로 직접 pull한다 (backend를 거치지 않음).
필요한 것: 워커 실행 환경에 **읽기 전용** 서비스 계정 키. 버킷의 `uploads/`
경로에 대해서만 권한 발급 (전체 버킷 접근 금지). `GOOGLE_APPLICATION_CREDENTIALS`
환경변수로 지정.

→ **TODO (정다희, GCP 담당)**: `uploads/` prefix 한정 read-only 서비스 계정 발급.

## 3. 콜백: 결과 보고

워커가 처리 완료 후 backend에 HTTP로 보고한다.

```
POST {BACKEND_API_BASE}/analysis/jobs/{job_id}/callback/
Header: X-Internal-Token: <INTERNAL_API_TOKEN>
Content-Type: application/json

{
  "status": "succeeded" | "failed",
  "result": { ... },
  "error_message": ""
}
```

`result`는 자유 형식 JSON — backend는 스키마 검증 없이 그대로 저장만 한다
(`JobCallbackSerializer.result`는 `JSONField`라 object/string/array 무엇이든
받는다). 워커가 실제로 넣는 키:

```json
{
  "stil_value": 42.0,
  "sigma": 5.0,
  "class_composition": {
    "tumor": 45.2,
    "stroma": 28.1,
    "immune": 15.3,
    "necrosis": 6.8,
    "other": 4.6
  },
  "lower": 37.0,
  "upper": 47.0,
  "abstain": false,
  "decision": "LOW",
  "n_valid": 128,
  "cp_value": 0.87,
  "medgemma_report": {"summary": "...", "generation_failed": false}
}
```

- `stil_value` / `lower` / `upper` / `sigma`: 0~100 스케일 (0~1 아님)
- `class_composition`: 5개 조직 분류 (`tumor`/`stroma`/`immune`/`necrosis`/`other`)
- `decision`: `"LOW"` / `"HIGH"` / `"ABSTAIN"` 중 하나
- `n_valid`, `cp_value`: 필수로 같이 보냄
- `medgemma_report`: 객체 (`{"summary": ..., "generation_failed": ...}`).
  backend는 타입 제약이 없어 object 그대로 받아도 문제 없음.

`status="failed"`일 때는 `error_message`를 채우고 `result`는 생략 가능.

## 4. INTERNAL_API_TOKEN

`backend/.env`와 `worker/.env`의 `INTERNAL_API_TOKEN` 값이 동일해야 한다.
값이 다르면 콜백이 조용히 401로 실패한다. 전달은 슬랙 DM으로 (평문 커밋 금지).

## 5. Redis

- 위치: GCP, backend(Cloud Run)와 같은 프로젝트에 올림.
- 스펙: e2-micro.
- **보안 필수 설정** (VM 세팅 담당자 확인):
  - `requirepass`로 비밀번호 설정
  - 방화벽으로 접속 IP 제한 (최소 Cloud Run 아웃바운드 + 워커 IP만 허용)
- `CELERY_BROKER_URL` 형식은 비밀번호 적용 후 `redis://:<password>@<host>:6379/0`
  으로 바뀐다. 확정되면 `backend/.env.example`, `worker/.env.example` 둘 다 갱신.

## 6. 현재 상태

- backend: `USE_MOCK_INFERENCE=true`로 로컬 검증 완료. 위 result 키 형태로
  mock 결과를 만들어 콜백 로직을 통과시킨 상태 (`apps/analysis/services.py`).
- worker: 실제 Celery 태스크(`worker/tasks.py`) 및 GCS pull, Mosec 연동은
  진행 중.
