def log_access(request, action, target_table, target_id=None, patient=None):
    """설계문서 12장 — 환자 식별정보 접근 시 audit_log를 남긴다.

    지연 임포트: apps.common은 accounts보다 먼저 로드되므로 모듈 최상단에서
    accounts.models를 import하면 순환 임포트가 될 수 있어 함수 안에서 임포트.
    """
    from apps.accounts.models import AuditLog

    user = request.user if request.user.is_authenticated else None
    AuditLog.objects.create(
        actor_user=user,
        action=action,
        target_table=target_table,
        target_id=target_id,
        patient=patient,
        ip=request.META.get("REMOTE_ADDR"),
        user_agent=request.META.get("HTTP_USER_AGENT", "")[:255],
    )
