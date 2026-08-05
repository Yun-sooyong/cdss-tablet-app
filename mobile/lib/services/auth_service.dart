<<<<<<< HEAD
import '../models/patient.dart';

class AuthService {
  Patient? _currentPatient;
  String _password = ''; // 목데이터용 — 서버 없이 로컬에서만 비교

  Patient? get currentPatient => _currentPatient;
  bool get isLoggedIn => _currentPatient != null;

  Future<Patient> loginWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (email.isEmpty || password.isEmpty) {
      throw Exception('이메일/비밀번호를 입력해줘');
    }
    _currentPatient = Patient(id: 'p1', name: '애옹씌', email: email);
    return _currentPatient!;
  }

  Future<Patient> loginWithSocial(String provider) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _currentPatient = Patient(
      id: 'p1',
      name: '애옹씌',
      email: '$provider@example.com',
    );
    return _currentPatient!;
  }

  Future<Patient> signUp({
=======
import 'dart:convert';
import 'api_client.dart';
import '../models/patient.dart';

class AuthService {
  Patient? currentPatient;
  final _client = ApiClient.instance;

  Future<void> loginWithEmail(String email, String password) async {
    final res = await _client.post('/api/v1/auth/login/', body: {
      'username': email,
      'password': password,
    });
    if (res.statusCode != 200) {
      throw Exception('로그인에 실패했어요. 이메일/비밀번호를 확인해주세요.');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _client.saveTokens(access: data['access'] as String, refresh: data['refresh'] as String);
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
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
    required String email,
    required String password,
    required String name,
    required DateTime birthDate,
<<<<<<< HEAD
    required String address,
    required String phone,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _password = password;
    _currentPatient = Patient(
      id: 'p1',
      name: name,
      email: email,
      birthDate: birthDate,
      address: address,
      phone: phone,
    );
    return _currentPatient!;
  }

  // 설정 화면 "개인정보 수정"에서 호출.
  Future<void> updateProfile({
    required String name,
    required DateTime birthDate,
    required String address,
    required String phone,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_currentPatient == null) return;
    _currentPatient = _currentPatient!.copyWith(
      name: name,
      birthDate: birthDate,
      address: address,
      phone: phone,
    );
  }

  // 설정 화면 "비밀번호 변경"에서 호출.
=======
    required Sex sex,
    required String address,
    required String phone,
  }) async {
    final body = {
      'email': email,
      'password': password,
      'name': name,
      'birth_date':
          '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
      'sex': sex.code,
      'phone': phone,
      'address': address,
    };
    final res = await _client.post('/api/v1/patients/register/', body: body);
    if (res.statusCode != 201) {
      throw Exception(_extractErrorMessage(res.body, '회원가입에 실패했어요.'));
    }
    await loginWithEmail(email, password);
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

  Future<void> loginWithSocial(String provider) async {
    await Future.delayed(const Duration(milliseconds: 400));
    currentPatient = Patient(
      id: 'mock-kakao-${DateTime.now().millisecondsSinceEpoch}',
      name: '카카오 사용자',
      signupProvider: provider,
    );
  }

>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
<<<<<<< HEAD
    await Future.delayed(const Duration(milliseconds: 500));
    if (currentPassword != _password) {
      throw Exception('현재 비밀번호가 일치하지 않아');
    }
    _password = newPassword;
  }

  void logout() {
    _currentPatient = null;
=======
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> linkKakao() async {
    await Future.delayed(const Duration(milliseconds: 400));
    currentPatient = currentPatient?.copyWith(kakaoLinked: true);
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  }
}
