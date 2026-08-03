class QrToken {
  final String token;
  final DateTime expiresAt;

  QrToken({required this.token, required this.expiresAt});

  Duration get remaining {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isExpired => remaining == Duration.zero;
}

class QrService {
  Future<QrToken> issue() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return QrToken(
      token: 'demo-token-${DateTime.now().millisecondsSinceEpoch}',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  Future<QrToken> reissue() => issue();
}
