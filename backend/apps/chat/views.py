import logging

from drf_spectacular.utils import extend_schema
from rest_framework import permissions
from rest_framework.exceptions import APIException
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.permissions import get_staff_or_403

from .serializers import FirebaseTokenSerializer

logger = logging.getLogger(__name__)


class ChatFirebaseTokenView(APIView):
    """POST /chat/firebase-token — 채팅용 Firebase 커스텀 토큰 발급.

    채팅 방/메시지는 Django DB가 아니라 Firestore에 클라이언트가 직접
    쓴다 (2026-08-05, 설계문서 9.1절 "REST 폴링 금지" 권고에 따라
    Firestore로 분리 결정). 하지만 로그인은 여전히 Django JWT라서,
    Firestore가 "이 요청자가 누구인지"를 알려면 Firebase Auth로 한 번
    더 인증해야 한다 — 그 다리 역할이 이 엔드포인트다.

    흐름: JWT로 이 API 호출 → Firebase 커스텀 토큰 발급 → 클라이언트가
    Firebase SDK의 signInWithCustomToken()으로 로그인 → 이후 Firestore
    보안 규칙이 request.auth.uid(=staff.id)로 방 멤버십을 검사한다.
    uid는 staff.id를 그대로 쓴다 — 환자 식별정보는 전혀 섞이지 않는다
    (docs/CHAT_INTERFACE.md 참고).
    """

    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=None, responses=FirebaseTokenSerializer)
    def post(self, request):
        staff = get_staff_or_403(request.user)

        from firebase_admin import auth

        from apps.accounts.firebase import get_firebase_app

        try:
            app = get_firebase_app()
            token_bytes = auth.create_custom_token(
                str(staff.id), {"role": staff.role}, app=app
            )
        except Exception as exc:  # 로컬 등 Firebase ADC 미설정 환경
            logger.warning("Firebase custom token 발급 실패: %s", exc)
            raise APIException(
                "채팅 인증 서버(Firebase) 연결에 실패했습니다.",
                code="firebase_unavailable",
            ) from None
        token = token_bytes.decode("utf-8")

        return Response(
            FirebaseTokenSerializer({"firebase_token": token, "uid": str(staff.id)}).data
        )
