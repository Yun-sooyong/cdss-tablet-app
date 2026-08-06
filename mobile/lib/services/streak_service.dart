import 'package:shared_preferences/shared_preferences.dart';

// 앱을 며칠 연속으로 열었는지 기기에만 저장해서 세는 서비스 — 서버 API 없이 동작.
// 어제도 열었으면 +1, 오늘 이미 기록했으면 그대로, 하루 이상 건너뛰면 1로 리셋.
class StreakService {
  StreakService._();
  static final instance = StreakService._();

  static const _lastOpenedKey = 'streak_last_opened_date';
  static const _countKey = 'streak_count';

  Future<int> recordVisitAndGetStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastOpenedStr = prefs.getString(_lastOpenedKey);
    if (lastOpenedStr == null) {
      await _save(prefs, today, 1);
      return 1;
    }

    final lastOpened = DateTime.parse(lastOpenedStr);
    final diffDays = today.difference(lastOpened).inDays;
    final currentCount = prefs.getInt(_countKey) ?? 1;

    final int newCount;
    if (diffDays <= 0) {
      newCount = currentCount; // 오늘 이미 기록함
    } else if (diffDays == 1) {
      newCount = currentCount + 1; // 어제도 열었음 — 연속 유지
    } else {
      newCount = 1; // 하루 이상 건너뜀 — 리셋
    }

    await _save(prefs, today, newCount);
    return newCount;
  }

  Future<void> _save(SharedPreferences prefs, DateTime day, int count) async {
    await prefs.setString(_lastOpenedKey, day.toIso8601String());
    await prefs.setInt(_countKey, count);
  }
}
