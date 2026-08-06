import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tablet/api/api.dart';

// 로그인 관련 상태, 앱 처음 시작시 unknown, 로그인, 로그아웃 상태
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends Notifier<AuthStatus> {
  bool _disposed = false;

  @override
  AuthStatus build() {
    ref.keepAlive();
    ref.onDispose(() => _disposed = true);
    _restore();
    return AuthStatus.unknown;
  }

  Future<void> _restore() async {
    final token = await ref.read(tokenStoreProvider).readAccess();
    if (_disposed) return;
    state = token == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
  }

  Future<void> login(String username, String password) async {
    await ref.read(authApiProvider).login(username, password);
    state = AuthStatus.authenticated;
  }

  Future<void> logout() async {
    await ref.read(authApiProvider).logout();
    state = AuthStatus.unauthenticated;
  }

  /// 인터셉터가 refresh까지 실패했을 때 (토큰은 이미 지워짐)
  void forceLogout() {
    if (_disposed) return;
    state = AuthStatus.unauthenticated;
  }
}

final authProvider = NotifierProvider<AuthController, AuthStatus>(
  AuthController.new,
);
