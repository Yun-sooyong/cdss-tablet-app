class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\-\.]+$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return '이메일을 입력해줘';
    if (!_emailRegex.hasMatch(value.trim())) return '이메일 형식이 올바르지 않아';
    return null;
  }

  static String? password(String? value, {int minLength = 8}) {
    if (value == null || value.isEmpty) return '비밀번호를 입력해줘';
    if (value.length < minLength) return '비밀번호는 $minLength자 이상이어야 해';
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return '비밀번호를 입력해줘';
    return null;
  }

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label을(를) 입력해줘';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return '전화번호를 입력해줘';
    final digitsOnly = value.trim().replaceAll('-', '');
    if (!RegExp(r'^01[0-9][0-9]{7,8}$').hasMatch(digitsOnly)) {
      return '전화번호 형식이 올바르지 않아 (예: 010-1234-5678)';
    }
    return null;
  }
}