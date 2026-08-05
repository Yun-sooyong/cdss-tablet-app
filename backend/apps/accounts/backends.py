from django.contrib.auth import get_user_model
from django.contrib.auth.backends import ModelBackend

from apps.patients.models import Patient

User = get_user_model()


class ChartNumberOrUsernameBackend(ModelBackend):
    """환자는 로그인 시 username(이메일) 대신 chart_number로도 인증할 수
    있다 (서정은 요청, 2026-08-05). API 필드명은 그대로 username이고,
    거기 chart_number 값을 넣어도 되는 방식 — 로그인 엔드포인트 계약은
    안 바뀐다.

    먼저 기존 방식(username+password)으로 시도하고, 실패하면 username
    값을 chart_number로 보고 연결된 Patient.user를 찾아 재검증한다.
    user=null인 워크인 환자(아직 회원가입 안 함)는 애초에 로그인할
    계정이 없으므로 대상에서 제외된다(user__isnull=False 조건).
    """

    def authenticate(self, request, username=None, password=None, **kwargs):
        user = super().authenticate(request, username=username, password=password, **kwargs)
        if user is not None:
            return user

        if not username or not password:
            return None

        patient = (
            Patient.objects.filter(
                chart_number=username, user__isnull=False, deleted_at__isnull=True
            )
            .select_related("user")
            .first()
        )
        if patient is None:
            return None

        candidate = patient.user
        if candidate.check_password(password) and self.user_can_authenticate(candidate):
            return candidate
        return None
