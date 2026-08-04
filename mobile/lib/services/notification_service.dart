import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dose.dart';

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  // 사용자가 아직 한 번도 설정을 안 바꿨을 때만 쓰는 기본값.
  static const Map<DoseTime, TimeOfDay> _defaultTimes = {
    DoseTime.morning: TimeOfDay(hour: 7, minute: 0),
    DoseTime.lunch: TimeOfDay(hour: 13, minute: 0),
    DoseTime.evening: TimeOfDay(hour: 18, minute: 0),
  };

  Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  String _prefsKey(DoseTime time) => 'dose_time_${time.name}';

  // 저장해둔 알림 시각을 불러온다. 저장된 게 없으면 기본값(7/13/18시).
  Future<Map<DoseTime, TimeOfDay>> loadDoseTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <DoseTime, TimeOfDay>{};
    for (final time in DoseTime.values) {
      final saved = prefs.getString(_prefsKey(time));
      if (saved != null) {
        final parts = saved.split(':');
        result[time] = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } else {
        result[time] = _defaultTimes[time]!;
      }
    }
    return result;
  }

  // 알림 시각 하나를 저장한다 — 설정 화면에서 시간 고를 때마다 호출.
  Future<void> saveDoseTime(DoseTime time, TimeOfDay newTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(time), '${newTime.hour}:${newTime.minute}');
  }

  // 오늘 복용 목록을 받아서 같은 시간대끼리 묶어 매일 반복 알림을 예약한다.
  // 시각은 항상 loadDoseTimes()로 저장된 값을 읽어와서 쓴다 — 하드코딩 안 함.
  Future<void> scheduleDailyDoseReminders(List<DoseItem> doses) async {
    final byTime = <DoseTime, List<String>>{};
    for (final dose in doses) {
      byTime.putIfAbsent(dose.time, () => []).add(dose.medicationName);
    }

    final doseTimes = await loadDoseTimes();

    for (final entry in byTime.entries) {
      final t = doseTimes[entry.key]!;
      await _scheduleDaily(
        id: entry.key.index,
        hour: t.hour,
        minute: t.minute,
        title: '${entry.key.label} 약 먹을 시간이에요',
        body: entry.value.join(', '),
      );
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dose_reminder_channel',
          '복약 알림',
          channelDescription: '복용 시간 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
