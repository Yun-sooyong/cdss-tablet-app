# 백엔드 요청 (일운 → 다희)

`origin/feature/dahee` 기준으로 확인한 내용입니다. 우선순위 순.

---

## 1. 계정 요청 → 발급 (신규)

초대코드를 없애고, 가입 희망자가 요청을 보내면 관리자가 계정을 만들어 아이디·임시 비밀번호를 메일로 보내는 흐름으로 바꿉니다.

```
가입 희망자 (React /signup · Flutter 로그인창)
  → 계정 요청 제출
  → 관리자 전원에게 알림
  → 관리자가 요청 목록에서 확인
  → 승인 → 서버가 계정 생성 + 임시 비밀번호를 1회 반환
  → 관리자가 복사해 메일 발송
```

### 1-1. 모델 `AccountRequest` (`apps/accounts/models.py`)

| 필드 | 타입 | 비고 |
|---|---|---|
| `id` | UUID | pk |
| `name` | CharField(100) | 신청자 실명 |
| `email` | EmailField | 발급 계정을 보낼 주소 |
| `role` | CharField(20) | 희망 직군. `Staff.Role` 값 |
| `department` | CharField(100, blank) | 희망 소속 |
| `note` | TextField(blank) | 신청 사유 |
| `status` | CharField(20) | `pending` / `approved` / `rejected` |
| `created_at` | DateTimeField | |
| `reviewed_at` | DateTimeField(null) | |
| `reviewed_by` | FK(staff.Staff, null) | |
| `created_user` | FK(User, null) | 승인 시 만들어진 계정 |

### 1-2. 알림

`Notification.Type`에 `ACCOUNT_REQUEST = "account_request"` 추가. 요청이 생기면 `role=admin`인 `Staff` 전원에게 `notify()`.

`target_type="account_request"`, `target_id=<요청 id>`로 보내주시면 알림에서 목록으로 보낼 수 있습니다.

프론트는 판독 콘솔 타입(`analysis_done`/`share`/`chat`)을 **제외한** 나머지를 관리 콘솔에 띄우게 해뒀으니, 타입 이름이 달라져도 그대로 뜹니다.

### 1-3. 엔드포인트

**`POST /api/v1/auth/account-requests/`** — 인증 불필요

```json
{ "name": "김의사", "email": "a@b.kr", "role": "doctor", "department": "병리과", "note": "" }
```
→ 201 `{ "id": "...", "status": "pending" }`
같은 이메일로 `pending`이 남아 있으면 400

**`GET /api/v1/auth/account-requests/`** — 관리자
`?status=pending` 필터, `-created_at` 정렬

**`POST /api/v1/auth/account-requests/{id}/approve/`** — 관리자

```json
{ "username": "doctor_kim", "role": "doctor", "department": "병리과" }
```
→ 200 **이 응답에서만 평문 비밀번호를 줍니다. 다시 조회 불가**
```json
{ "username": "doctor_kim", "temporary_password": "Xk92mQ4vR" }
```
- `User` + `Staff` 생성, `status=approved`, `reviewed_by`/`reviewed_at`/`created_user` 기록
- 임시 비밀번호는 서버 생성 (`secrets.token_urlsafe(9)` 정도)
- 중복 `username`이면 400
- 첫 로그인 후 변경 강제가 필요하면 `User.must_change_password` 추가 (선택). 변경 자체는 기존 `POST /auth/password/change`로 됩니다

**`POST /api/v1/auth/account-requests/{id}/reject/`** — 관리자
`{ "reason": "" }` → 204

### 1-4. 초대코드 제거

`invitations/redeem/`을 **부르는 클라이언트가 없습니다** (backend URL과 openapi.yaml에만 존재). 새 흐름이 붙으면 `Invitation` 모델과 두 엔드포인트를 같이 걷어내면 됩니다.

---

## 2. `needs_review_count`를 ABSTAIN 기준으로

`apps/analysis/views.py`의 `with_batch_counts()`

지금은 `status IN (stil_done, succeeded)` — 결과가 나온 job 전부입니다. 화면이 세는 "확인 필요"는 `result.decision == 'ABSTAIN'`뿐이라 숫자가 안 맞습니다. 슬라이드 10장 중 8장 완료·2장 유보면 서버는 8, 화면은 2를 원합니다.

```python
needs_review_count=Count(
    "images__jobs",
    filter=Q(images__jobs__status__in=[Job.Status.STIL_DONE, Job.Status.SUCCEEDED])
           & Q(images__jobs__result__decision="ABSTAIN"),
    distinct=True,
),
```

`result`가 JSONField라 Postgres에서 바로 질의됩니다.

**이게 오면 판독 목록의 N+1이 통째로 사라집니다.** 지금은 배치마다 상세를 다시 부르고 있어서, 배치가 N개면 요청이 N+1번 나갑니다.

---

## 3. 배치 목록 규모 대응

`BatchListCreateView.get` — 쿼리 파라미터를 하나도 안 받고 페이지네이션도 없습니다. 1000건이 넘으면 응답이 한 번에 다 오고 화면이 1000행을 한꺼번에 그립니다.

- `?limit=` / `?offset=` (또는 커서)
- `?patient=<uuid>`, `?status=`, 기간 필터
- `?q=` — 차트번호·이름 부분일치 서버 검색. 페이지를 끊는 순간 클라이언트 검색이 무너져서 같이 필요합니다
- `select_related("patient")` — 지금 배치 1000개를 직렬화하면 환자 조회가 1000번 따로 나가고 복호화가 2000번 돕니다. 한 줄이면 없어집니다
- 인덱스: `Batch.created_at`, `Job.created_at`, `Batch.status`, `Job.status` — 목록 정렬·필터가 전부 이 컬럼을 쓰는데 인덱스가 없습니다

---

## 4. `image_summary`에 `batch` 추가

`ImageSummarySerializer.Meta.fields`가 `["id", "original_filename"]`뿐입니다. `batch`가 있으면

- 결과 상세(`/results/:jobId`)의 브레드크럼이 배치를 되찾습니다 (지금은 끊겨 있어 빼놨습니다)
- `GET /analysis/jobs/` 결과를 배치별로 묶을 수 있어 2번 없이도 확인 필요 수를 셀 수 있습니다

---

## 5. 공유 실패 메시지

소유자가 아닌 배치를 공유하려 하면 DRF 기본 문구인 `No Batch matches the given query.`가 그대로 화면에 뜹니다. 한국어 메시지로 바꿔주세요.

프론트에서는 목록을 본인 소유 배치로 걸러 이 상황이 안 생기게 해뒀지만, 메시지 자체는 남아 있습니다.