import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_client.dart';

/// 파이어베이스 기기 토큰을 발급받아 서버(POST /api/v1/devices/tokens/)에 등록.
/// 로그인된 상태에서만 호출해야 함 — 이 엔드포인트가 인증 필요라서.
class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance =
      PushNotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _client = ApiClient.instance;

  Future<void> registerDeviceToken() async {
    // iOS는 권한 요청 필수, 안드로이드는 13 미만이면 이 호출이 사실상 no-op.
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return; // 사용자가 알림 거부 — 서버에 등록 안 하고 조용히 끝냄
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _sendTokenToServer(token);
    }

    // 토큰은 앱 재설치·OS 백업 복원 등으로 언제든 바뀔 수 있어.
    // 바뀔 때마다 여기서 자동으로 다시 등록해줘야 서버가 옛날 토큰으로 헛쏘는 걸 막음.
    _messaging.onTokenRefresh.listen(_sendTokenToServer);
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await _client.post('/api/v1/devices/tokens/', body: {
        'fcm_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (_) {
      // 토큰 등록 실패해도 로그인 자체는 이미 성공한 상태라 앱 흐름은 안 막음.
      // 조용히 넘어가되, 계속 실패하면 알림 자체가 안 오니까 나중에 로그 확인은 필요.
    }
  }
}
