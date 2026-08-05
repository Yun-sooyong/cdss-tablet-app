# 계정 요청 → 발급 (백엔드 요청)

초대코드를 없애고, 관리자가 직접 계정을 만들어 아이디·임시 비밀번호를 메일로 보내는 흐름으로 바꾼다.

```
가입 희망자 (React /signup · Flutter 로그인창)
  → 계정 요청 제출
  → 관리자 전원에게 알림
  → 관리자가 요청 목록에서 확인
  → 승인 → 서버가 계정 생성 + 임시 비밀번호를 1회 반환
  → 관리자가 복사해 메일 발송
```

## 1. 모델 `AccountRequest`

`backend/apps/accounts/models.py`

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

## 2. 알림

`Notification.Type`에 `ACCOUNT_REQUEST = "account_request"` 추가. 요청이 생기면 `role=admin`인 `Staff` 전원에게 `notify()`.

프론트는 판독 콘솔 타입(`analysis_done` / `share` / `chat`)을 **제외**한 나머지를 관리 콘솔에 띄우므로, 타입 이름이 달라도 그대로 뜬다.

`target_type="account_request"`, `target_id=<요청 id>`로 보내주면 알림 클릭 시 목록으로 보낼 수 있다.

## 3. 엔드포인트

### `POST /api/v1/auth/account-requests/` — 인증 불필요

```json
{ "name": "김의사", "email": "a@b.kr", "role": "doctor", "department": "병리과", "note": "" }
```

201 → `{ "id": "...", "status": "pending" }`

같은 이메일로 `pending`이 남아 있으면 400.

### `GET /api/v1/auth/account-requests/` — 관리자

`?status=pending` 필터. 목록은 `-created_at`.

### `POST /api/v1/auth/account-requests/{id}/approve/` — 관리자

```json
{ "username": "doctor_kim", "role": "doctor", "department": "병리과" }
```

`User` + `Staff` 생성, `status=approved`, `reviewed_by`/`reviewed_at`/`created_user` 기록.

200 → **이 응답에서만 평문 비밀번호를 준다. 다시 조회할 수 없다.**

```json
{ "username": "doctor_kim", "temporary_password": "Xk92mQ4vR" }
```

- 임시 비밀번호는 서버 생성 (`secrets.token_urlsafe(9)` 정도)
- 이미 있는 `username`이면 400
- 첫 로그인 후 변경을 강제하려면 `User.must_change_password` BooleanField 추가 (선택). 변경 자체는 기존 `POST /auth/password/change`로 된다

### `POST /api/v1/auth/account-requests/{id}/reject/` — 관리자

`{ "reason": "" }` → 204

## 4. 초대코드는 아직 지우지 말 것

Flutter가 `POST /auth/invitations/redeem/`을 쓰고 있다. 새 흐름이 React·Flutter 양쪽에 붙은 뒤에 제거한다.