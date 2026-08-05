<<<<<<< HEAD
=======
import 'dart:convert';
import 'api_client.dart';

// 와이어프레임 4번 "QR 발급" 화면 대응 — "환자 확인용 QR", 유효시간 5분, 1회용, 재발급 버튼.
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
class QrToken {
  final String token;
  final DateTime expiresAt;

  QrToken({required this.token, required this.expiresAt});

<<<<<<< HEAD
=======
  factory QrToken.fromJson(Map<String, dynamic> json) {
    return QrToken(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  Duration get remaining {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isExpired => remaining == Duration.zero;
}

class QrService {
<<<<<<< HEAD
  Future<QrToken> issue() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return QrToken(
      token: 'demo-token-${DateTime.now().millisecondsSinceEpoch}',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
=======
  final _client = ApiClient.instance;

  Future<QrToken> issue() async {
    final res = await _client.post('/api/v1/patients/me/qr/');
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('QR 발급에 실패했어요.');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return QrToken.fromJson(data);
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  }

  Future<QrToken> reissue() => issue();
}
