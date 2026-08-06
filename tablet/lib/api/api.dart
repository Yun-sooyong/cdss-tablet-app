/// 서버와 말하는 모든 것 — 주소 · 경로 · 토큰 저장 · Dio · 인증 인터셉터.
///
/// 한 파일로 모아둔 이유: 이 조각들은 서로를 참조해서 파일을 나누면
/// 순환 import가 생기고, 전체가 200줄 남짓이라 나눌 실익이 없다.
library;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tablet/providers/auth_provider.dart';

// ---------------------------------------------------------------- 주소 · 경로

class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://medai-backend-XXXXXXXXXX.asia-northeast3.run.app',
  );
}

/// ⚠️ 경로는 전부 '/' 로 끝난다.
/// 빼면 301 리다이렉트가 나고 POST는 body가 유실된다.
abstract final class Endpoints {
  // auth
  static const login = '/api/v1/auth/login/';
  static const refresh = '/api/v1/auth/login/refresh/';
  static const logout = '/api/v1/auth/logout/';

  /// 계정 발급 신청. **로그인 불필요** — 초대코드 방식을 대체한다.
  /// (`/auth/invitations/redeem/` 과 `/staff/invitations/` 는 서버에서 삭제됐다)
  static const accountRequests = '/api/v1/auth/account-requests/';

  // staff
  static const staff = '/api/v1/staff/';
  static const staffMe = '/api/v1/staff/me/';

  // QR — 태블릿(의료진) 전용. 환자 앱이 만든 일회성 토큰을 검증한다
  static const qrVerify = '/api/v1/qr/verify/';

  // 알림
  static const deviceTokens = '/api/v1/devices/tokens/';
  static const notifications = '/api/v1/notifications/';
  static const notificationsReadAll = '/api/v1/notifications/read-all/';
  static String notification(String id) => '/api/v1/notifications/$id/';

  // patients
  static const patients = '/api/v1/patients/';
  static const patientSearch = '/api/v1/patients/search/';

  // analysis
  static const batches = '/api/v1/analysis/batches/';
  static const modelVersions = '/api/v1/analysis/model-versions/';

  static String batch(String id) => '$batches$id/';
  static String batchImages(String id) => '$batches$id/images/';
  static String batchStart(String id) => '$batches$id/start/';
  static String batchShares(String id) => '$batches$id/shares/';
  static String share(String shareId) => '/api/v1/analysis/shares/$shareId/';
  static String job(String id) => '/api/v1/analysis/jobs/$id/';

  /// 판정 유보(ABSTAIN) 확정. **role=doctor 만 가능하다**
  static String jobReview(String id) => '/api/v1/analysis/jobs/$id/review/';
}

// ------------------------------------------------------------------ 토큰 저장

/// ⚠️ SharedPreferences는 평문이라 의료 앱에 부적절하다
class TokenStore {
  static const _storage = FlutterSecureStorage();
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  Future<String?> readAccess() => _storage.read(key: _kAccess);
  Future<String?> readRefresh() => _storage.read(key: _kRefresh);

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> saveAccess(String access) =>
      _storage.write(key: _kAccess, value: access);

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}

// -------------------------------------------------------------- 인증 인터셉터

/// access 토큰이 5분이라 401은 일상이다. 동시에 나간 요청이 각자 refresh를
/// 호출하면 토큰이 서로를 무효화하므로, refresh는 한 번만 돌리고
/// 나머지는 그 결과를 기다린다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens, this._retryDio, this._onAuthFailure);

  final TokenStore _tokens;
  final Dio _retryDio;
  final void Function() _onAuthFailure;

  /// 진행 중인 refresh 하나를 모두가 공유한다 (single-flight)
  Future<String?>? _refreshing;

  /// 인증이 필요 없는 경로. logout은 인증이 필요하므로 여기 없다
  static const _noAuth = {
    Endpoints.login,
    Endpoints.refresh,
    Endpoints.accountRequests, // POST는 로그인 불필요 (GET은 관리자 전용)
  };

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_noAuth.contains(options.path)) {
      final access = await _tokens.readAccess();
      if (access != null) options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;

    final notAuthError = err.response?.statusCode != 401;
    final alreadyRetried = req.extra['__retried'] == true;
    if (notAuthError || alreadyRetried || _noAuth.contains(req.path)) {
      return handler.next(err);
    }

    final newAccess = await _refreshOnce();
    if (newAccess == null) {
      await _tokens.clear();
      _onAuthFailure(); // → redirect가 로그인 화면으로 보낸다
      return handler.next(err);
    }

    req.extra['__retried'] = true; // 재시도는 1회만
    req.headers['Authorization'] = 'Bearer $newAccess';
    try {
      handler.resolve(await _retryDio.fetch(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<String?> _refreshOnce() {
    // 이미 누가 돌리고 있으면 그 Future를 그대로 돌려준다
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null) return null;
    try {
      // 인터셉터 없는 별도 Dio — 재귀 방지
      final bare = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      final res = await bare.post(
        Endpoints.refresh,
        data: {'refresh': refresh},
      );
      final access = res.data['access'] as String;
      await _tokens.saveAccess(access);
      return access;
    } on DioException {
      return null;
    }
  }
}

// ------------------------------------------------------------------- 프로바이더

final tokenStoreProvider = Provider<TokenStore>((ref) {
  ref.keepAlive();
  return TokenStore();
});

final dioProvider = Provider<Dio>((ref) {
  ref.keepAlive();

  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30), // Cloud Run 콜드 스타트
      receiveTimeout: const Duration(seconds: 60),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      ref.read(tokenStoreProvider),
      dio,
      // ⚠️ 지연 읽기. 밖으로 빼면 authProvider ↔ dioProvider 순환이 된다
      () => ref.read(authProvider.notifier).forceLogout(),
    ),
  );

  return dio;
});

// ---------------------------------------------------------------------- 인증 API

class AuthApi {
  AuthApi(this._dio, this._tokens);
  final Dio _dio;
  final TokenStore _tokens;

  /// ⚠️ 필드는 email 이 아니라 username 이다
  Future<void> login(String username, String password) async {
    final res = await _dio.post(
      Endpoints.login,
      data: {'username': username, 'password': password},
    );
    await _tokens.save(
      access: res.data['access'] as String,
      refresh: res.data['refresh'] as String,
    );
  }

  /// 계정 발급 신청. 로그인 없이 부른다.
  ///
  /// 신청자가 아이디·비밀번호를 정하지 않는다 — 관리자가 승인하면 서버가
  /// 임시 비밀번호를 만들어 관리자에게만 한 번 보여주고, 관리자가 전달한다.
  /// 같은 이메일로 대기 중인 신청이 있으면 서버가 막는다.
  Future<void> requestAccount({
    required String name,
    required String email,
    required String role, // doctor | nurse | admin
    String department = '',
    String note = '',
  }) async {
    await _dio.post(
      Endpoints.accountRequests,
      data: {
        'name': name,
        'email': email,
        'role': role,
        'department': department,
        'note': note,
      },
    );
  }

  Future<void> logout() async {
    // 지우기 전에 읽어야 한다
    final refresh = await _tokens.readRefresh();
    try {
      if (refresh != null) {
        await _dio.post(Endpoints.logout, data: {'refresh': refresh});
      }
    } on DioException {
      // 서버 폐기에 실패해도 로컬 로그아웃은 반드시 진행한다
    } finally {
      await _tokens.clear();
    }
  }
}

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(dioProvider), ref.watch(tokenStoreProvider)),
);
