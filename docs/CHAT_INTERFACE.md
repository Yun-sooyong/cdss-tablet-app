# 채팅 (React ↔ Flutter tablet 공유) 계약

React(최일운)와 tablet(윤수용) 둘 다 이 문서 기준으로 채팅을 붙인다.
확정일: 2026-08-05.

---

## 왜 이런 구조인가

설계문서 9.1절이 "REST 폴링으로 채팅을 만들면 안 된다"고 못박아뒀고,
Django Channels(WebSocket) 대신 **Firestore로 분리**하기로 결정했다
(Cloud Run WebSocket은 인스턴스가 여러 개로 늘면 Redis channel layer가
추가로 필요해서 지금 인원/일정엔 부담).

문제는 우리 로그인이 Firebase Auth가 아니라 Django JWT라는 것 — 그래서
Firestore가 "이 요청자가 누구인지" 알게 하려면 다리가 하나 필요하다.

```
1. 평소처럼 로그인 → POST /api/v1/auth/login/  (JWT 받음)
2. POST /api/v1/chat/firebase-token/  (JWT로 인증)
   → { "firebase_token": "...", "uid": "<staff.id>" }
3. 클라이언트: Firebase SDK의 signInWithCustomToken(firebase_token)
4. 이후 Firestore 읽기/쓰기는 Firebase Auth 세션으로 진행
   (request.auth.uid == staff.id로 Firestore 보안 규칙이 방 멤버십을 검사함)
```

**주의**: Firebase 커스텀 토큰은 보통 1시간 후 만료된다. 앱을 오래 켜두면
Firebase SDK가 알아서 만료를 감지하니, 그때 2번부터 다시 하면 된다
(Django JWT 자체가 만료됐으면 로그인부터 다시).

Firebase 프로젝트: `model-platform-502402` (백엔드가 이미 FCM에 쓰던 것과
동일 프로젝트). 클라이언트 쪽 Firebase 설정값(apiKey 등)은 각자
Firebase 콘솔 → 프로젝트 설정에서 가져가면 된다 (다희님한테 Owner 권한
요청).

---

## Firestore 데이터 구조

```
chat_rooms/{roomId}
  room_type: "direct" | "group"
  created_by: string   // staff.id
  member_ids: string[] // staff.id 목록, 본인 포함 필수
  created_at: Timestamp

chat_rooms/{roomId}/messages/{messageId}
  sender_id: string    // staff.id, 본인만 생성 가능
  body: string
  attached_batch_id: string | null   // batch UUID만. 환자 정보 절대 넣지 말 것
  created_at: Timestamp
  deleted_at: Timestamp | null       // soft delete — body를 지우지 말고 이 필드만 세팅

chat_rooms/{roomId}/reads/{uid}      // uid == 본인 staff.id인 문서만 쓸 수 있음
  last_read_message_id: string
  last_read_at: Timestamp
```

**환자 식별정보(이름·생년월일·주소·전화번호)는 Firestore에 절대 넣지 않는다**
(설계문서 9.1절 "의료 관련 내용은 넣지 않는 규칙 필요"). `attached_batch_id`로
배치를 공유하고 싶으면 UUID만 메시지에 담고, 화면에 환자 이름 등을 보여줘야
하면 그 UUID로 `GET /api/v1/analysis/batches/{id}/`를 **따로** 호출해서
`patient_summary`를 가져다 쓸 것.

## Firestore 보안 규칙

저장소 루트 `firestore.rules`에 정의되어 있다 — 방 멤버(`member_ids`에
포함된 staff)만 읽기/쓰기 가능, 메시지는 `sender_id`가 본인이어야 생성
가능, 수정은 `deleted_at` 필드만 허용(소프트 삭제). 규칙을 바꿔야 하면
그 파일을 고치고 `firebase deploy --only firestore:rules`로 배포 —
누구든 Firebase 콘솔 Editor 이상 권한 있으면 가능하다 (다희님한테 요청).

## 아직 안 정해진 것 (필요해지면 논의)

- 방 생성/멤버 초대 UI 흐름 (전원이 room 문서를 직접 create 하는지, 특정
  역할만 group 방을 만들 수 있는지)
- 안 읽은 메시지 뱃지 계산 — `reads/{uid}.last_read_message_id`와
  최신 메시지를 클라이언트가 비교하는 방식으로 우선 생각 중
- 메시지 페이지네이션/무한스크롤 전략
