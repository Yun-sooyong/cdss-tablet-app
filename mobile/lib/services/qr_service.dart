import 'dart:convert';
import 'api_client.dart';

// 와이어프레임 4번 "QR 발급" 화면 대응 — "환자 확인용 QR", 유효시간 5분, 1회용, 재발급 버튼.
class QrToken {
  final String token;
  final DateTime expiresAt;

  QrToken({required this.token, required this.expiresAt});

  factory QrToken.fromJson(Map<String, dynamic> json) {
    return QrToken(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  Duration get remaining {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isExpired => remaining == Duration.zero;
}

class QrService {
  final _client = ApiClient.instance;

  Future<QrToken> issue() async {
    final res = await _client.post('/api/v1/patients/me/qr/');
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('QR 발급에 실패했어요.');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return QrToken.fromJson(data);
  }

  Future<QrToken> reissue() => issue();
}
