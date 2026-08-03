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
    required String email,
    required String password,
    required String name,
    required DateTime birthDate,
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
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (currentPassword != _password) {
      throw Exception('현재 비밀번호가 일치하지 않아');
    }
    _password = newPassword;
  }

  void logout() {
    _currentPatient = null;
  }
}
