# medical-ai-platform

의료 영상 분석 플랫폼. 상세 설계는 `docs/백엔드_리팩토링_설계문서.docx` 참조.

---

## 1. 모듈 구성

| 폴더 | 내용 | 배포 위치 | 담당 |
|---|---|---|---|
| `backend/` | Django REST API | GCP Cloud Run | 정다희 |
| `worker/` | Celery 워커 + 추론 파이프라인 | 학원 workstation | 박검모 |
| `shared/` | Flutter 공유 패키지 (theme / api / models / auth) | 패키지 | 공용 |
| `mobile/` | Flutter 환자용 앱 | 앱 스토어 | 서정은 |
| `tablet/` | Flutter 의료진용 앱 | 원내 배포 | 윤수용 |
| `react/` | React 웹 | Vercel | 최일운 |

`backend`와 `worker`는 코드를 공유하지 않는다. 태스크 이름(`analysis.run_job`)과
payload 키만으로 연결되며, 이 때문에 워커에는 DB 접속 정보를 두지 않는다.

---

## 2. 시작하기

```bash
cd backend
pip install -r ../requirements.txt
python manage.py migrate        # accounts/0001_initial 포함, 이미 커밋되어 있음
python manage.py runserver
```

로컬 DB는 sqlite다. Postgres 없이 바로 실행된다.
`db.sqlite3`는 `.gitignore`에 있으니 커밋되지 않는다.

---

## 3. ⚠️ 커스텀 User 모델 — 이미 만들어 둔 이유

`AUTH_USER_MODEL`은 **최초 `migrate` 이후에 교체할 수 없다.**

Django의 마이그레이션은 사용자 참조를 `swappable_dependency(AUTH_USER_MODEL)`로
기록하고, 이 기록이 DB의 `django_migrations` 테이블에 남는다. 기본 User로 한 번이라도
migrate를 돌린 뒤 `AUTH_USER_MODEL`을 바꾸면 이미 적용된 마이그레이션이 가리키던 대상이
사라져 에러가 나고, 마이그레이션을 추가해서 해결할 수 없다. **DB 드롭 + 마이그레이션 파일
전체 삭제 후 재시작**이 유일한 복구 방법이다.

혼자 1일차면 3분이면 되지만, 팀원 4명이 clone해서 각자 로컬 DB를 만든 뒤라면
전원에게 "DB 드롭하고 다시 받아라"를 공지해야 한다. 그래서 첫 커밋에 넣어 두었다.

```python
# apps/accounts/models.py
class User(AbstractUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
```

필드는 앞으로 얼마든지 추가해도 된다(평범한 마이그레이션이다).
되돌릴 수 없는 것은 *교체 행위*이지 필드 구성이 아니다.

---

## 4. 지금 커밋되어 있는 것

### 내용이 있는 파일

```
.gitignore                          시크릿 패턴 포함
requirements.txt                    공통 의존성 (torch 계열은 주석)
backend/manage.py
backend/config/settings/{base,local,prod}.py
backend/config/{urls,wsgi}.py
backend/apps/accounts/models.py     커스텀 User
backend/apps/accounts/migrations/0001_initial.py
backend/apps/*/apps.py              7개 앱, label 명시
backend/.env.example
worker/.env.example
```

### 비어 있지만 지우면 안 되는 것

- `__init__.py` — Python 패키지 인식용. 특히 `migrations/__init__.py`가 없으면
  Django가 그 앱의 마이그레이션을 아예 찾지 못한다.
- `.gitkeep` — 빈 폴더를 git에 올리기 위한 자리표시자. 실제 파일이 생기면 지워도 된다.

### 왜 `apps.py`에 `label`이 있나

앱이 `apps/` 하위에 있으면 Django가 app_label을 `apps.analysis`로 잡아 마이그레이션
경로가 꼬인다. `label = "analysis"`를 명시해 고정했다.

### 일부러 만들지 않은 것

`models.py`(accounts 제외), `views.py`, `serializers.py`, `urls.py`,
`pubspec.yaml`, `package.json`, `main.dart` 등은 각 프레임워크의 생성 명령이
만들어 주므로 미리 두지 않았다.

---

## 5. 협의가 필요한 것

### 착수 전 (막히는 항목)

| 항목 | 주도 | 왜 지금인가 |
|---|---|---|
| Redis 위치 + 접속정보 | 최일운 | 없으면 워커가 아예 안 돈다. GCP에 둘지, Memorystore냐 e2-micro냐, 비밀번호·TLS |
| API 응답 샘플 JSON | 정다희 | 프론트 3명이 여기서 풀린다. 구현 말고 응답 모양만 (7절 참조) |
| ~~부트스트랩 담당~~ | 윤수용 | 완료 |
| ~~User 모델~~ | — | 완료 |

### 이번 주

- **컬러 팔레트** — mobile/tablet은 `shared/lib/theme`으로 강제되지만 React는 별도라
  사람이 맞춰야 한다
- **shared 범위 선 긋기** — theme / api / models / auth 까지. 화면 위젯이 들어가면
  두 담당자가 같은 파일을 계속 건드리게 되어 분리한 이점이 사라진다
- **React web 담당** — 미정 상태로는 일정이 안 나온다. 인원이 없으면 1차 범위에서
  빼는 결정을 내리는 편이 낫다
- **백엔드 분담** — 20개 테이블 + serializer + view + permission을 한 명이 짜면
  프론트 3명이 대기하게 된다. 도메인별로 나눌지, 순서대로 내보낼지 결정 필요
- **실제 환자 데이터 사용 여부** — 공개 데이터셋만 쓰면 암호화·감사로그 강도를 낮출 수
  있고, 실데이터라면 IRB가 필요하다. 뒤로 미룰수록 되돌리기 비싸다
- **torch 버전** — 각자 설치하면 추론 결과가 달라질 수 있다. 학원 GPU 확인 후 고정값 공유

### 진행하면서

- 채팅 방식 (Django Channels vs Firebase) — 채팅 착수 직전
- 권한 규칙 문장화 — "의료진은 자기 batch + 공유받은 batch만" 같은 문장을 먼저 합의하고
  코드로 옮긴다. 나중에 얹으면 누락된 엔드포인트를 찾기 어렵다
- 시연·발표일 워크스테이션 가동 보장 — 기술로 못 푸는 문제

---

## 6. 공유 파일과 충돌 규칙

| 파일 | 만지는 사람 | 규칙 |
|---|---|---|
| `shared/lib/models/*.dart` | 윤수용, 서정은 (+정다희 영향) | **가장 자주 깨질 곳.** 백엔드 필드가 바뀌면 여기가 바뀌고 두 앱이 동시에 영향받는다 |
| `shared/pubspec.yaml` | 윤수용, 서정은 | 패키지 추가마다 충돌 후보. 초기 의존성은 함께 정한다 |
| `backend/apps/*/migrations/` | 정다희 (+모델 건드리는 사람) | 로컬에서 각자 `makemigrations` 금지. 같은 번호 파일이 여러 개 생긴다. 자기 앱만 지정: `makemigrations <앱이름>` |
| `backend/apps/accounts/`, `common/` | 전원 간접 영향 | User·BaseModel이라 다른 앱이 전부 의존. 변경 시 공지 |
| `docs/openapi.yaml` | 정다희 생성 → 프론트 3명 소비 | API 변경 시 재생성 후 커밋 |
| `requirements.txt` | 전원 | 추가 시 알리기 |
| `.env.example` | 정다희, 최일운 | 키를 추가하면 다른 사람 로컬이 깨진다. 반드시 공지 |

### 특히 위험한 두 가지 — 파일이 아니라 "값"

| 항목 | 맞춰야 하는 사람 | 왜 위험한가 |
|---|---|---|
| `INTERNAL_API_TOKEN` | 정다희 ↔ 최일운 | 양쪽 값이 다르면 워커 콜백이 401. 조용히 실패한다 |
| 태스크 이름 + payload 키 | 정다희 ↔ 최일운 | `analysis.run_job`과 kwargs. 코드를 공유하지 않으므로 컴파일 에러도 안 나고, 작업이 큐에 쌓이기만 한다 |

이 두 가지는 `worker/INTERFACE.md`에 계약으로 적어 두고, 변경 시 양쪽을 같은 PR에서
고친다.

```python
# backend — 작업 등록
app.send_task(
    "analysis.run_job",
    kwargs={
        "job_id": str(job.id),
        "image_key": image.storage_key,
        "model_version_id": str(mv.id),
        "conformal_q": mv.conformal_q,
    },
    queue="gpu",
)

# worker/tasks.py — 같은 이름으로 등록
@app.task(name="analysis.run_job", bind=True, max_retries=2)
def run_job(self, job_id, image_key, model_version_id, conformal_q):
    ...
```

payload에 **환자 정보가 없다**는 점이 보안 요구사항이다. 워커는 `job_id`만 알고,
환자 연결은 결과 조회 시 서버가 조인한다.

---

## 7. 프론트엔드 — API 없이 화면 먼저

API를 기다릴 필요는 없다. 다만 각자 상상한 응답 구조가 다르면 통합할 때 위젯 트리를
다시 건드리게 되므로, 데이터 모양만 먼저 맞춘다.

1. 정다희 님이 **응답 JSON 예시**만 던진다 (구현 말고 샘플. 반나절)
2. 그걸로 `shared/lib/models`에 DTO를 만든다
3. 프론트는 하드코딩 더미 데이터로 화면 작업
4. API가 나오면 데이터 소스만 갈아끼운다

DTO를 `shared`에 둔 이유가 여기서 값을 한다. mobile·tablet이 같은 `Batch` 클래스를
쓰므로 필드명이 바뀌어도 한 곳만 고치면 된다.

**DTO는 필드를 최소로 두는 게 낫다.** 화면에 실제로 쓰는 것만. 미리 다 채워두면
나중에 안 쓰는 필드까지 고치게 된다.

지금 대기 없이 가능한 작업:

- **mobile (서정은)** — 로그인, 예약 확인/수정, 복약 캘린더, 진료내역, QR. 전부 더미로 가능
- **tablet (윤수용)** — 컬러 확정 후 `shared/lib/theme` 먼저, 그 다음 대시보드·상세보기
- **react** — 담당 미정

---

## 8. 개발 순서

### 1단계 — 세로 슬라이스 관통

테이블 전체를 만들고 시작하지 않는다. 아래 한 줄이 끝까지 도는 것을 먼저 확인한다.

```
로그인 → 이미지 업로드(서명 URL) → batch 생성 → 큐 등록
     → 워커(mock)가 집어감 → 결과 콜백 → 조회
```

필요한 테이블은 `user / staff / batch / image / job / model_version` 6개뿐이다.
`USE_MOCK_INFERENCE=true`로 두면 학원 컴퓨터 없이 전 구간을 돌릴 수 있고, 동시에
워커 pull 방식이 실제로 동작하는지 검증된다.

**전부 만들 것이지만, 순서가 중요하다.** 슬라이스를 뚫어보면 거의 항상 스키마가 바뀐다.
6개 상태에서 발견하면 마이그레이션 하나로 끝나지만, 20개를 만들어 둔 뒤라면 연쇄로
고쳐야 한다.

### 2단계 이후

1. invitation · 소셜 로그인 · 권한 필터(queryset 기본값)
2. patient · staff · 코드 테이블 (식별정보 암호화 포함)
3. reservation + reservation_history
4. visit · diagnosis · disease
5. 복약 5개 테이블 + 복약률 계산
6. analysis_share + 대시보드 조회 범위
7. 실 Mosec 연동 (mock → 실서버)
8. FCM 알림 · 채팅
9. audit_log · 탈퇴/보존 정책 · worker_heartbeat · 모니터링

모델 개수와 엔드포인트 개수는 같지 않다. `reservation_history`는 서버가 자동으로 쌓고,
`dose_schedule`은 `/medications/schedule` 응답에 묶여 나가며, `audit_log`와
`worker_heartbeat`는 클라이언트에 나가지 않는다.
