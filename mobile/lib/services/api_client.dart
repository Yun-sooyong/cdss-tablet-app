import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  static const String baseUrl =
      'https://medai-backend-XXXXXXXXXX.asia-northeast3.run.app';

  final _storage = const FlutterSecureStorage();
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<String?> get accessToken => _storage.read(key: _accessKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshKey);

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  Future<bool> get isLoggedIn async => (await accessToken) != null;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<http.Response> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) =>
      _send('POST', path, body: body);

  Future<http.Response> patch(String path, {Map<String, dynamic>? body}) =>
      _send('PATCH', path, body: body);

  Future<http.Response> delete(String path) => _send('DELETE', path);

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) async {
    final uri = _uri(path, query);
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await accessToken;
    if (token != null) headers['Authorization'] = 'Bearer $token';

    http.Response res;
    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: headers);
        break;
      case 'POST':
        res = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PATCH':
        res = await http.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'DELETE':
        res = await http.delete(uri, headers: headers);
        break;
      default:
        throw ArgumentError('unsupported method: $method');
    }

    if (res.statusCode == 401 && !isRetry && token != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(method, path, query: query, body: body, isRetry: true);
      }
    }
    return res;
  }

  Future<bool> _tryRefresh() async {
    final refresh = await refreshToken;
    if (refresh == null) return false;
    final res = await http.post(
      _uri('/api/v1/auth/login/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );
    if (res.statusCode != 200) {
      await clearTokens();
      return false;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _storage.write(key: _accessKey, value: data['access'] as String);
    return true;
  }
}
