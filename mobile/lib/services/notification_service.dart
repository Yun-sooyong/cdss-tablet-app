import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dose.dart';

// 설정 화면 카드 하나(약 하나)에 뿌릴 슬롯 정보.
class DoseTimeSlotSetting {
  final DoseTime time;
  TimeOfDay timeOfDay;
  bool enabled;

  DoseTimeSlotSetting({
    required this.time,
    required this.timeOfDay,
    required this.enabled,
  });
}

// 약 하나 + 그 약이 오늘 갖고 있는 시간대 슬롯들.
class MedicationReminderGroup {
  final String medicationName;
  final List<DoseTimeSlotSetting> slots;

  MedicationReminderGroup({required this.medicationName, required this.slots});
}

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _enabledKey = 'notifications_enabled';

  Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings: initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  // 알림 전체 켜짐/꺼짐 — settings_screen.dart가 쓰는 거, 안 건드림.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (!value) {
      await _plugin.cancelAll();
    }
  }

  String _timeKey(String medicationName, DoseTime time) =>
      'dose_time_${medicationName}_${time.name}';
  String _slotEnabledKey(String medicationName, DoseTime time) =>
      'dose_slot_enabled_${medicationName}_${time.name}';

  // 저장된 시각이 없으면 처방 스케줄의 실제 시각(defaultTime)을 기본값으로 씀 —
  // 07:00 같은 임의 기본값보다, 실제 그 약이 처방된 시각이 훨씬 정확한 기본값이라 이렇게 감.
  Future<TimeOfDay> _loadTime(
      String medicationName, DoseTime time, TimeOfDay defaultTime) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_timeKey(medicationName, time));
    if (saved == null) return defaultTime;
    final parts = saved.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<bool> _loadSlotEnabled(String medicationName, DoseTime time) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_slotEnabledKey(medicationName, time)) ?? true;
  }

  Future<void> saveDoseTimeFor(
      String medicationName, DoseTime time, TimeOfDay newTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _timeKey(medicationName, time), '${newTime.hour}:${newTime.minute}');
  }

  Future<void> setSlotEnabled(
      String medicationName, DoseTime time, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_slotEnabledKey(medicationName, time), value);
  }

  // 오늘 복용 목록을 "약 이름"으로 묶고, 그 안에서 다시 "시간대"로 묶어서
  // 설정 화면 카드에 그대로 뿌릴 수 있는 형태로 만들어준다.
  Future<List<MedicationReminderGroup>> loadReminderGroups(
      List<DoseItem> doses) async {
    final byMedication = <String, List<DoseItem>>{};
    for (final dose in doses) {
      byMedication.putIfAbsent(dose.medicationName, () => []).add(dose);
    }

    final groups = <MedicationReminderGroup>[];
    for (final entry in byMedication.entries) {
      final medicationName = entry.key;
      final slots = <DoseTimeSlotSetting>[];
      for (final time in DoseTime.values) {
        final dosesForSlot = entry.value.where((d) => d.time == time).toList();
        if (dosesForSlot.isEmpty) continue; // 그 시간대에 이 약 스케줄이 없으면 슬롯 자체를 안 만듦
        final defaultTime = TimeOfDay.fromDateTime(dosesForSlot.first.date);
        slots.add(DoseTimeSlotSetting(
          time: time,
          timeOfDay: await _loadTime(medicationName, time, defaultTime),
          enabled: await _loadSlotEnabled(medicationName, time),
        ));
      }
      groups.add(MedicationReminderGroup(
          medicationName: medicationName, slots: slots));
    }
    return groups;
  }

  // "약 + 시간대" 조합마다 매일 반복 알림을 예약한다.
  Future<void> scheduleDailyDoseReminders(List<DoseItem> doses) async {
    final enabled = await isEnabled();
    if (!enabled) {
      await _plugin.cancelAll();
      return;
    }

    // 매번 싹 지우고 다시 예약 — 약 구성이 바뀌거나 슬롯을 꺼도 옛날 알림이 안 남게.
    await _plugin.cancelAll();

    final groups = await loadReminderGroups(doses);
    for (final group in groups) {
      for (final slot in group.slots) {
        if (!slot.enabled) continue;
        await _scheduleDaily(
          id: _notificationId(group.medicationName, slot.time),
          hour: slot.timeOfDay.hour,
          minute: slot.timeOfDay.minute,
          title: '${slot.time.label} 약 먹을 시간이에요',
          body: group.medicationName,
        );
      }
    }
  }

  // 안드로이드 알림 id는 정수 하나라, 약 이름+시간대 조합을 정수 하나로 안정적으로 변환.
  int _notificationId(String medicationName, DoseTime time) =>
      ('${medicationName}_${time.name}').hashCode & 0x7FFFFFFF;

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
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
