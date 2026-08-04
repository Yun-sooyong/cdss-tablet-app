def notify(user, notif_type, body, target_type="", target_id=None):
    """알림 생성. 설계문서 6.9절/9장 — 실제 FCM 발송(firebase-admin)은 아직
    미구현(Firebase 프로젝트 자체가 없음)이라, 지금은 notification 레코드만
    남긴다. device_token이 있으면 나중에 여기서 실제 푸시를 보내면 된다.
    """
    from .models import DeviceToken, Notification

    has_token = DeviceToken.objects.filter(user=user).exists()
    Notification.objects.create(
        user=user,
        type=notif_type,
        body=body,
        target_type=target_type,
        target_id=target_id,
        sent_result="skipped_no_fcm_credentials" if has_token else "no_device_token",
    )
