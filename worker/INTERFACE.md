# backend ↔ worker 계약

backend(정다희)와 worker(박검모)는 코드를 공유하지 않는다. 태스크 이름과
payload 키, 콜백 엔드포인트만으로 연결된다. 이 문서가 계약의 기준이며,
변경 시 양쪽을 같은 PR에서 고친다.

확정일: 2026-08-03 (result 필드 상세는 2026-08-03 2차 수정, 콜백 2단계 구조는
2026-08-03 3차 수정, model_name 추가는 2026-08-03 4차 수정)

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
        "model_name": mv.name,              # 예: "attention_unet_v1" — model_registry 조회 키
        "conformal_q": mv.conformal_q,
    },
    queue="gpu",
)
```

`model_name`은 `ModelVersion.name` 값 그대로다. 워커의 `model_registry.py`가
`"unet_v1"` / `"attention_unet_v1"` 같은 **이름 문자열**로 모델을 찾기 때문에
`model_version_id`(UUID)만으로는 조회가 안 돼서 추가했다 (박검모 발견,
2026-08-03). 지금 backend에 등록된 값은 `til-scoring-attention-unet`인데,
워커 쪽 `model_registry.py`의 키 이름과 정확히 일치해야 한다 — 다르면
`ModelVersion.name`을 워커 레지스트리 키에 맞춰 갱신할 것.

payload에 환자 정보는 없다. 워커는 `job_id`만 알고, 환자 연결은 결과 조회 시
backend가 조인한다.

## 2. 이미지 다운로드

워커가 GCS에서 `image_key`로 직접 pull한다 (backend를 거치지 않음).
필요한 것: 워커 실행 환경에 **읽기 전용** 서비스 계정 키. 버킷의 `uploads/`
경로에 대해서만 권한 발급 (전체 버킷 접근 금지). `GOOGLE_APPLICATION_CREDENTIALS`
환경변수로 지정.

→ **TODO (정다희, GCP 담당)**: `uploads/` prefix 한정 read-only 서비스 계정 발급.

## 3. 콜백: 결과 보고 (2단계)

MedGemma 리포트 생성에 시간이 걸리므로, 워커는 **콜백을 두 번** 보낸다.
엔드포인트/바디 구조는 매번 동일하고 `status` 값만 다르다.

```
POST {BACKEND_API_BASE}/analysis/jobs/{job_id}/callback/
Header: X-Internal-Token: <INTERNAL_API_TOKEN>
Content-Type: application/json

{
  "status": "stil_done" | "succeeded" | "failed",
  "result": { ... },
  "error_message": ""
}
```

**시퀀스**:
1. sTIL·Conformal 끝나면 `status="stil_done"`으로 1차 콜백 — `medgemma_report` 없이 나머지 필드만.
2. MedGemma 리포트까지 끝나면 `status="succeeded"`로 2차 콜백 — `medgemma_report`만 보내도 됨.
3. 어느 단계에서든 실패하면 `status="failed"`로 **한 번만** 콜백 (그 시점까지의 진행 상황과 무관하게 종료).

backend는 `result`를 **덮어쓰지 않고 기존 값에 병합(merge)** 한다
(`apps/analysis/services.py`의 `apply_job_result`). 그래서 2차 콜백은
`medgemma_report`만 보내도 되고, 혹시 전체를 다시 다 보내도 문제없다 —
같은 키는 최신 값으로 갱신될 뿐이다. `result`는 스키마 검증 없는
자유 형식 JSON(`JSONField`)이라 object/string 무엇이든 받는다.

1차 콜백(`stil_done`)에서 워커가 넣는 키:

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
  "cp_value": 0.87
}
```

2차 콜백(`succeeded`)에서 워커가 넣는 키:

```json
{
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

**프론트 영향**: `Job.status`가 `stil_done`일 때는 "sTIL 분석 완료, 리포트
작성 중" 같은 중간 상태 UI가 필요하다. `finished_at`은 `succeeded`/`failed`
에서만 채워지고 `stil_done`에서는 비어있다 — 진행 중임을 이걸로 구분 가능.

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
