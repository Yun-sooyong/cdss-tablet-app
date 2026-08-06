import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tablet/providers/batch_provider.dart';
import 'package:tablet/providers/notification_provider.dart';

/// 백그라운드에서 메시지를 받을 때 호출된다.
///
/// ⚠️ **최상위 함수여야 한다.** 별도 isolate에서 실행되므로 앱 상태에 접근할 수 없고,
/// Firebase도 여기서 다시 초기화해야 한다. 지금은 표시만 하고 아무것도 안 한다
/// (시스템 트레이 알림은 OS가 알아서 띄운다).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[push] background: ${message.messageId}');
}

enum PushStatus {
  /// google-services.json 이 없거나 초기화 실패 — 푸시 없이 동작한다
  unavailable,

  /// 사용자가 알림 권한을 거부했다
  denied,

  /// 토큰까지 받아 서버에 등록됐다
  ready,
}

class PushState {
  const PushState({this.status = PushStatus.unavailable, this.token, this.error});

  final PushStatus status;
  final String? token;
  final String? error;
}

/// FCM 등록·수신을 담당한다.
///
/// **로그인 이후에** [register] 를 부른다 — 토큰 등록 API가 인증을 요구한다.
class PushController extends Notifier<PushState> {
  bool _handlersWired = false;

  @override
  PushState build() => const PushState();

  /// 앱 시작 시 한 번. Firebase가 없으면 조용히 넘어간다.
  static Future<bool> initFirebase() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      return true;
    } catch (e) {
      // google-services.json 이 없으면 여기서 실패한다. 앱은 계속 떠야 한다.
      debugPrint('[push] Firebase 미설정 — 푸시 없이 진행: $e');
      return false;
    }
  }

  /// 로그인 뒤 호출. 권한 요청 → 토큰 획득 → 서버 등록 → 수신 핸들러 연결.
  Future<void> register() async {
    if (Firebase.apps.isEmpty) {
      state = const PushState(status: PushStatus.unavailable);
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Android 13+ 는 런타임 권한이 필요하다
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        state = const PushState(status: PushStatus.denied);
        return;
      }

      final token = await messaging.getToken();
      if (token == null) {
        state = const PushState(
          status: PushStatus.unavailable,
          error: 'FCM 토큰을 받지 못했습니다',
        );
        return;
      }

      await _send(token);
      _wireHandlers(messaging);
      state = PushState(status: PushStatus.ready, token: token);
    } catch (e) {
      state = PushState(status: PushStatus.unavailable, error: '$e');
    }
  }

  Future<void> _send(String token) {
    return ref.read(analysisRepositoryProvider).registerDeviceToken(
      token,
      Platform.isIOS ? 'ios' : 'android',
    );
  }

  void _wireHandlers(FirebaseMessaging messaging) {
    if (_handlersWired) return;
    _handlersWired = true;

    // 토큰은 갱신될 수 있다. 바뀌면 서버에 다시 올린다.
    messaging.onTokenRefresh.listen((t) {
      state = PushState(status: state.status, token: t);
      _send(t).ignore();
    });

    // 앱이 떠 있을 때 도착한 메시지. 분석이 끝났을 수 있으니 목록을 새로 받는다.
    FirebaseMessaging.onMessage.listen((m) {
      debugPrint('[push] foreground: ${m.notification?.title}');
      _refreshTarget(m);
    });

    // 알림을 눌러 앱이 열린 경우
    FirebaseMessaging.onMessageOpenedApp.listen(_refreshTarget);
  }

  void _refreshTarget(RemoteMessage m) {
    ref.invalidate(batchesProvider);
    ref.invalidate(notificationsProvider); // 알림함·배지도 같이 갱신
    final batchId = m.data['target_id'] as String?;
    if (batchId != null && batchId.isNotEmpty) {
      ref.invalidate(batchDetailProvider(batchId));
    }
  }
}

final pushProvider = NotifierProvider<PushController, PushState>(
  PushController.new,
);
