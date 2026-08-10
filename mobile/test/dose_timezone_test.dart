import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/dose.dart';

void main() {
  test('doses are bucketed by Korea time regardless of device timezone', () {
    // KST = UTC+9 (no DST): 08:00 KST = 23:00 UTC (prev day),
    // 13:00 KST = 04:00 UTC, 18:00 KST = 09:00 UTC.
    final morning = DoseItem.fromScheduleJson(
      {'id': '1', 'scheduled_at': '2026-08-06T23:00:00Z', 'is_taken': false},
      '아침약',
      null,
    );
    final lunch = DoseItem.fromScheduleJson(
      {'id': '2', 'scheduled_at': '2026-08-07T04:00:00Z', 'is_taken': false},
      '점심약',
      null,
    );
    final evening = DoseItem.fromScheduleJson(
      {'id': '3', 'scheduled_at': '2026-08-07T09:00:00Z', 'is_taken': false},
      '저녁약',
      null,
    );

    expect(morning.time, DoseTime.morning, reason: '08:00 KST should be morning');
    expect(lunch.time, DoseTime.lunch, reason: '13:00 KST should be lunch');
    expect(evening.time, DoseTime.evening, reason: '18:00 KST should be evening');
  });
}
