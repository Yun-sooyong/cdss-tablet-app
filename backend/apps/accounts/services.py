import logging

logger = logging.getLogger(__name__)


def notify(user, notif_type, body, target_type="", target_id=None):
    """알림 생성 + 등록된 device_token이 있으면 실제 FCM 푸시도 보낸다.

    설계문서 6.9절/9장. 푸시 발송 실패는 알림 생성 자체를 막으면 안 되므로
    (분석 완료 처리 흐름 중에 호출되기 때문에) 절대 예외를 밖으로 던지지
    않는다 — 실패해도 notification 레코드는 남고 sent_result에 사유만
    기록한다.
    """
    from .models import DeviceToken, Notification

    tokens = list(DeviceToken.objects.filter(user=user).values_list("fcm_token", flat=True))

    sent_result = "no_device_token"
    if tokens:
        sent_result = _send_fcm(tokens, body)

    Notification.objects.create(
        user=user,
        type=notif_type,
        body=body,
        target_type=target_type,
        target_id=target_id,
        sent_result=sent_result,
    )


def _send_fcm(tokens, body):
    try:
        from firebase_admin import messaging

        from .firebase import get_firebase_app

        app = get_firebase_app()
    except Exception as exc:  # Firebase 미설정(로컬 등) — mock으로 취급
        logger.warning("FCM app init failed, skipping push: %s", exc)
        return "skipped_fcm_unavailable"

    sent, failed = 0, 0
    for token in tokens:
        try:
            messaging.send(
                messaging.Message(
                    notification=messaging.Notification(
                        title="medical-ai-platform", body=body
                    ),
                    token=token,
                ),
                app=app,
            )
            sent += 1
        except Exception as exc:  # 만료/무효 토큰 등 — 다른 토큰은 계속 시도
            logger.warning("FCM send failed for token %s...: %s", token[:8], exc)
            failed += 1

    return f"sent:{sent}/failed:{failed}"
