import '../models/patient.dart';

class AuthService {
  Patient? _currentPatient;

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

  // 구글/카카오 버튼 공용 — provider: 'google' | 'kakao'
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
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _currentPatient = Patient(id: 'p1', name: name, email: email);
    return _currentPatient!;
  }

  void logout() {
    _currentPatient = null;
  }
}
