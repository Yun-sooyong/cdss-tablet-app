import 'dart:convert';
import 'api_client.dart';
import '../models/patient.dart';

class AuthService {
  Patient? currentPatient;
  final _client = ApiClient.instance;

  // 저장된 토큰이 있으면 그걸로 로그인 상태 복구를 시도한다.
  // fetchCurrentPatient()가 401을 만나면 ApiClient가 알아서 refresh를 한 번 시도하니까,
  // 여기까지 실패하면 refresh 토큰도 죽은 거라 완전 로그아웃 처리하는 게 맞다.
  Future<bool> tryAutoLogin() async {
    if (!await _client.isLoggedIn) return false;
    try {
      await fetchCurrentPatient();
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> login(String username, String password) async {
    final res = await _client.post('/api/v1/auth/login/', body: {
      'username': username,
      'password': password,
    });
    if (res.statusCode != 200) {
      throw Exception('로그인에 실패했어요. 아이디/비밀번호를 확인해줘.');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _client.saveTokens(
        access: data['access'] as String, refresh: data['refresh'] as String);
    await fetchCurrentPatient();
  }

  Future<void> fetchCurrentPatient() async {
    final res = await _client.get('/api/v1/patients/me/');
    if (res.statusCode != 200) {
      throw Exception('내 정보를 불러오지 못했어요.');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    currentPatient = Patient.fromJson(data, previous: currentPatient);
  }

  Future<void> signUp({
    required String username, // 로그인 아이디 — TODO: 백엔드 확인 후 body key 이름 교체 여부 결정
    required String password,
    required String name,
    String? chartNumber,
    DateTime? birthDate,
    Sex? sex,
    String? phone,
    String? address,
  }) async {
    final body = <String, dynamic>{
      'email': username, // TODO: 다희 확인 후 필요하면 'username' 등으로 교체
      'password': password,
      'name': name,
    };
    if (chartNumber != null && chartNumber.isNotEmpty) {
      body['chart_number'] = chartNumber;
    }
    if (birthDate != null) {
      body['birth_date'] =
          '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
    }
    if (sex != null) body['sex'] = sex.code;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    if (address != null && address.isNotEmpty) body['address'] = address;

    final res = await _client.post('/api/v1/patients/register/', body: body);
    if (res.statusCode != 201) {
      throw Exception(_extractErrorMessage(res.body, '회원가입에 실패했어요.'));
    }
    await login(username, password);
  }

  String _extractErrorMessage(String body, String fallback) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data.isNotEmpty) {
        final v = data.values.first;
        if (v is List && v.isNotEmpty) return v.first.toString();
        return v.toString();
      }
      if (data is List && data.isNotEmpty) return data.first.toString();
    } catch (_) {}
    return fallback;
  }

  Future<void> updateProfile({
    String? name,
    DateTime? birthDate,
    String? address,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (birthDate != null) {
      body['birth_date'] =
          '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
    }
    if (address != null) body['address'] = address;
    if (phone != null) body['phone'] = phone;

    final res = await _client.patch('/api/v1/patients/me/', body: body);
    if (res.statusCode != 200) {
      throw Exception('정보 수정에 실패했어요.');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    currentPatient = Patient.fromJson(data, previous: currentPatient);
  }

  Future<void> deleteAccount() async {
    final res = await _client.delete('/api/v1/patients/me/');
    if (res.statusCode != 204) {
      throw Exception('회원 탈퇴에 실패했어요.');
    }
    await logout();
  }

  Future<void> logout() async {
    final refresh = await _client.refreshToken;
    if (refresh != null) {
      try {
        await _client.post('/api/v1/auth/logout/', body: {'refresh': refresh});
      } catch (_) {}
    }
    await _client.clearTokens();
    currentPatient = null;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }
}
