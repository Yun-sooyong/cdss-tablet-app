# Flutter ↔ Django API 연동

Flutter 앱(mobile / tablet)이 백엔드에 붙는 방법. 클라이언트 코드는
`shared/lib/api`·`shared/lib/auth`에 두므로 두 앱이 공유한다.

> 이 문서의 엔드포인트·필드는 **배포된 서버의 OpenAPI 스키마를 실제로 받아서** 정리했다.
> 기준: 2026-08-03. 최신본은 항상 `/api/schema/`가 정답이다.

---

## 1. 서버 주소

배포는 GCP Cloud Run (`asia-northeast3`, project `model-platform-502402`).

| 용도 | URL |
| --- | --- |
| **개발/시연용 baseUrl** | `https://medai-backend-xxxxxxxxxx-du.a.run.app` |
| 동일 서비스 (신형 주소) | `https://medai-backend-XXXXXXXXXX.asia-northeast3.run.app` |
| API 문서 (브라우저) | `<base>/api/docs/` |
| OpenAPI 스키마 | `<base>/api/schema/` |

- **HTTPS이고 인터넷에 공개돼 있다**(`roles/run.invoker` = `allUsers`).
  GCP 로그인·서비스 계정 키 없이 그냥 호출하면 된다. 인증은 앱 레벨 JWT만 쓴다.
- HTTPS라서 Android 평문 트래픽 설정(`usesCleartextTraffic`)이 **필요 없다.**
  로컬 백엔드에 붙을 때만 필요하다 (7절).

### baseUrl은 코드에 박지 않는다

```bash
flutter run --dart-define=API_BASE_URL=https://medai-backend-xxxxxxxxxx-du.a.run.app
```

```dart
const baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://medai-backend-xxxxxxxxxx-du.a.run.app',
);
```

로컬 백엔드로 전환할 때 코드를 고치지 않기 위해서다.

---

## 2. 지금 열려 있는 엔드포인트 (실측)

전부 `Authorization: Bearer <access>` 필요. 예외는 표에 표시.

| 메서드 | 경로 | 용도 |
| --- | --- | --- |
| POST | `/api/v1/auth/login/` | 로그인 → `{access, refresh}` · **인증 불필요** |
| POST | `/api/v1/auth/login/refresh/` | 토큰 재발급 · **인증 불필요** |
| POST | `/api/v1/auth/invitations/redeem/` | 초대코드로 가입 · **인증 불필요** |
| POST | `/api/v1/staff/invitations/` | 초대코드 발급 (관리자만) |
| GET | `/api/v1/analysis/batches/` | 분석 목록 → `Batch[]` |
| POST | `/api/v1/analysis/batches/` | 배치 생성 |
| POST | `/api/v1/analysis/batches/{batch_id}/images/` | 이미지 등록 → **서명 URL** 발급 |
| POST | `/api/v1/analysis/images/{image_id}/jobs/` | 분석 작업 생성 |
| GET | `/api/v1/analysis/jobs/{job_id}/` | 작업 상태·결과 조회 |
| GET | `/api/v1/analysis/model-versions/` | 업로드 화면 모델 드롭다운 |
| POST | `/api/v1/analysis/jobs/{job_id}/callback/` | **워커 전용.** 앱은 호출하지 않음 |

### 아직 없는 것

`GET /api/v1/analysis/batches/{id}/` (배치 상세), 공유(`analysis_share`), 채팅, 환자/진료.
와이어프레임에 있는 `공유`·`공유 현황`은 **서버에 아직 없다.**

> ⚠️ 위 뷰들은 **`feature/dahee` 브랜치에만 있고 `main`에는 아직 병합되지 않았다.**
> `main`·`feature/sooyong`의 `backend/config/urls.py`는 `api/v1/`이 TODO 상태다.
> 즉 **배포된 서버가 `main`보다 앞서 있다.** 백엔드 코드를 읽어야 하면
> `git fetch` 후 `git show origin/feature/dahee:backend/config/urls.py` 로 확인한다.

---

## 3. 인증

```
POST /api/v1/auth/login/          {"username": "...", "password": "..."}  → {access, refresh}
POST /api/v1/auth/login/refresh/  {"refresh": "..."}                      → {access}
이후 모든 요청:  Authorization: Bearer <access>
```

> **로그인 필드는 `email`이 아니라 `username`이다.**
> `tablet/lib/screens/login_screen.dart`는 지금 이메일 입력창으로 되어 있다.
> 라벨을 바꾸든, 이메일을 그대로 `username`으로 보내든 맞춰야 한다.

가입은 초대코드 방식이다. 로그인 화면의 `아이디 발급 요청` 버튼이 이것에 해당한다.

```
POST /api/v1/auth/invitations/redeem/
{"code": "...", "username": "...", "email": "...", "password": "..."}   # password 8자 이상
```

동작 규칙:

1. 로그인 성공 → `access`·`refresh` 저장
2. 인터셉터가 요청마다 `Authorization` 부착
3. `401` → `refresh`로 재발급 → 원 요청 1회 재시도
4. 재발급도 실패 → 토큰 삭제 후 로그인 화면

주의 두 가지:

- **저장은 `flutter_secure_storage`.** `SharedPreferences`는 평문이라 의료 앱에 부적절하다.
- **동시 401.** 대시보드처럼 요청이 여러 개 동시에 나가면 401도 동시에 뜬다. refresh를
  요청 수만큼 호출하면 토큰이 서로를 무효화한다. **refresh는 1회만 돌리고 나머지는 결과를
  기다리게** 만든다.

---

## 4. 분석 한 건이 도는 순서

```
1. POST /analysis/batches/                        → batch.id
2. POST /analysis/batches/{batch_id}/images/      → {image.id, upload_url}
       body: {"original_filename": "slide.svs"}
3. PUT  <upload_url>                              → GCS에 파일 직접 업로드 (서버 경유 X)
4. GET  /analysis/model-versions/                 → model_version.id 선택
5. POST /analysis/images/{image_id}/jobs/         → job.id
       body: {"model_version_id": "..."}
6. GET  /analysis/jobs/{job_id}/                  → status가 끝날 때까지 폴링
```

`upload_url`은 GCS 서명 URL이다. 파일 바이트는 Django를 거치지 않고 GCS로 바로 올라간다.

### 상태값

| `Batch.status` | `Job.status` |
| --- | --- |
| `pending` 대기 | `queued` 대기 |
| `processing` 처리중 | `running` 실행중 |
| `done` 완료 | `stil_done` sTIL 완료 (리포트 대기) |
| `failed` 실패 | `succeeded` 성공 / `failed` 실패 |

**푸시가 없으므로 폴링해야 한다.** WebSocket·SSE 엔드포인트는 없다.
2~3초 간격으로 `GET /jobs/{id}/`를 치고, 화면을 벗어나면 타이머를 반드시 정리한다.
`stil_done`은 끝이 아니다 — sTIL은 나왔지만 리포트가 남은 중간 상태다.

---

## 5. DTO — 서버가 실제로 주는 필드

`shared/lib/models`에 이 모양 그대로 만든다.

```
Batch          id(uuid) · status · created_by(uuid) · created_at · updated_at
Job            id · image(uuid) · model_version(uuid) · status · result(nullable, 자유형)
               · error_message · started_at · finished_at · created_at
ModelVersion   id · name · version · conformal_q(double) · is_active · created_at
ImageUpload    id · batch · storage_key · original_filename · created_at · upload_url
```

확정된 규약:

- **id는 전부 문자열 UUID** (`#1042` 같은 정수 번호는 없다)
- **날짜는 ISO8601 date-time** — `DateTime.parse()`로 그대로 파싱
- **`GET /batches/`는 페이지네이션 없이 배열을 그대로 준다.** 지금은 단순하지만 건수가
  늘면 바뀔 자리다. 목록 화면은 페이징이 붙을 수 있다고 보고 짠다.

---

## 6. ⚠️ 와이어프레임과 스키마의 간극 (요청할 것)

대시보드 와이어프레임이 요구하는 값 중 **서버에 없는 것**들이다. 화면을 그리기 전에
정다희 님과 맞춰야 한다.

| 화면에 필요한 것 | 현재 `Batch` | 필요한 것 |
| --- | --- | --- |
| `환자 · 김○○` | 환자 필드 **없음** | `patient_name` 또는 `patient_id` |
| `배치 #1042` | `id`가 UUID | 사람이 읽을 짧은 번호 (없으면 UUID 앞 8자리로 대체) |
| `진행중 3/8` | 진행률 **없음** | `total_images` / `done_images` 집계 |
| `sTIL · Conformal 요약` | `Job.result`가 자유형 | result **스키마 확정** |
| `공유` / `공유받음` | 엔드포인트 **없음** | `analysis_share` (README 8절 6순위) |
| 배치 상세 화면 | `GET /batches/{id}/` **없음** | 상세 조회 추가 |

그때까지는 이 필드들을 **더미로 채워** 화면을 진행한다 (README 7절).

---

## 7. Flutter 쪽 구조

```
shared/lib/
  api/
    api_config.dart        baseUrl (dart-define 주입)
    api_client.dart        HTTP 인스턴스 + 인터셉터 조립
    endpoints.dart         경로 상수
    analysis_api.dart      도메인별 호출 함수
  auth/
    token_store.dart       secure storage 읽기/쓰기
    auth_interceptor.dart  Bearer 부착 + 401 재발급
  models/
    batch.dart, job.dart, model_version.dart
```

- HTTP 패키지는 **`dio` 권장**. 3절의 인터셉터·재시도를 `http`로 직접 짜면 요청마다 반복된다.
  단 `shared/pubspec.yaml`은 윤수용·서정은 공동 소유다(README 6절) — **추가 전 합의.**
- 화면이 API를 직접 호출하지 않게 사이에 한 겹 둔다. 그래야 "데이터 소스만 갈아끼운다"가
  실제로 성립한다.

```dart
abstract class BatchRepository { Future<List<Batch>> fetchBatches(); }

class MockBatchRepository implements BatchRepository { ... }  // 지금
class HttpBatchRepository implements BatchRepository { ... }  // 붙일 때
```

### 로컬 백엔드에 붙일 때만 필요한 것

| 실행 환경 | baseUrl |
| --- | --- |
| Windows 데스크톱 / iOS 시뮬레이터 | `http://localhost:8000` |
| **Android 에뮬레이터** | **`http://10.0.2.2:8000`** ← `localhost` 아님 |
| 실기기 (같은 Wi-Fi) | `http://<PC의 LAN IP>:8000` |

- 서버는 `python manage.py runserver 0.0.0.0:8000`으로 띄운다 (기본값은 자기 PC만 본다)
- `local.py`의 `ALLOWED_HOSTS = ["*"]`라 호스트 제한은 없다
- Android 9+ 평문 차단 → **디버그 빌드에만** 예외:
  `android/app/src/debug/AndroidManifest.xml`에 `android:usesCleartextTraffic="true"`.
  `src/main/`에 넣으면 운영 빌드까지 평문이 허용된다

---

## 8. 스모크 테스트

앱에 붙이기 전에 터미널에서 먼저 통과시킨다. 앱에서 디버깅하면 원인이 앱인지 서버인지
구분이 안 된다.

```bash
curl -X POST https://medai-backend-xxxxxxxxxx-du.a.run.app/api/v1/auth/login/ -H "Content-Type: application/json" -d "{\"username\":\"<계정>\",\"password\":\"<비번>\"}"
```

```bash
curl https://medai-backend-xxxxxxxxxx-du.a.run.app/api/v1/analysis/batches/ -H "Authorization: Bearer <access>"
```

브라우저로 `/api/docs/`를 열면 Swagger UI에서 직접 호출해 볼 수도 있다.

---

## 9. 증상별 원인

| 증상 | 원인 |
| --- | --- |
| `401` 인데 방금 로그인함 | `Bearer ` 접두사 누락, 또는 `access` 대신 `refresh`를 보냄 |
| `401` 이 반복 | refresh 동시 호출로 토큰이 서로 무효화 (3절) |
| 로그인 `400` | 필드명이 `email`. **`username`**이어야 한다 |
| `404` | 경로 끝 슬래시 누락. 전부 `/`로 끝난다 (`/batches/`) |
| Cloud Run 첫 호출만 느림 | 콜드 스타트. 타임아웃을 30초 이상으로 |
| `Connection refused` (에뮬레이터, 로컬 서버) | `localhost` 사용 → `10.0.2.2` |
| `CleartextNotPermitted` | 로컬 `http://`에 붙는 중. 7절의 debug 매니페스트 |
| CORS 오류 | 네이티브가 아니라 **web으로 실행 중**이다. 네이티브 앱엔 CORS가 적용되지 않는다 |

---

## 10. 지금 할 일

- [ ] 6절 표를 정다희 님께 전달 — 특히 **환자명·진행률·batch 상세 조회**
- [ ] `Job.result` 스키마 확정 (sTIL·Conformal 요약 표시에 필요)
- [ ] 서정은 님과 `shared/pubspec.yaml`에 `dio` 추가 합의
- [ ] 테스트 계정 발급 (또는 초대코드) — 스모크 테스트용
- [ ] 그 사이 화면은 `MockBatchRepository`로 진행
