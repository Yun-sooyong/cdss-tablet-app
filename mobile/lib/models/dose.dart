enum DoseTime { morning, lunch, evening }

extension DoseTimeLabel on DoseTime {
  String get label {
    switch (this) {
      case DoseTime.morning:
        return '아침';
      case DoseTime.lunch:
        return '점심';
      case DoseTime.evening:
        return '저녁';
    }
  }
}

DoseTime doseTimeFromHour(int hour) {
  if (hour < 11) return DoseTime.morning;
  if (hour < 17) return DoseTime.lunch;
  return DoseTime.evening;
}

// 한국은 UTC+9 고정(서머타임 없음). 기기 OS 타임존이 한국이 아닌 환경(에뮬레이터, 웹, CI 등)에서는
// .toLocal()이 엉뚱한 시각을 돌려줘서 아침/점심/저녁이 잘못 갈리니까, 기기 설정에 기대지 않고
// 여기서 직접 한국 시각으로 변환한다.
DateTime toKoreaTime(DateTime dateTime) =>
    dateTime.toUtc().add(const Duration(hours: 9));

DateTime nowInKorea() => toKoreaTime(DateTime.now());

// KST 캘린더 날짜(년/월/일)의 자정을 실제 UTC 시각으로 변환 — API 쿼리 범위에 씀.
DateTime koreaMidnightUtc(DateTime koreaDate) =>
    DateTime.utc(koreaDate.year, koreaDate.month, koreaDate.day)
        .subtract(const Duration(hours: 9));

class DoseItem {
  final String id;
  final DateTime date;
  final DoseTime time;
  final String medicationName;
  final double? remainingPercent;
  bool taken;

  DoseItem({
    required this.id,
    required this.date,
    required this.time,
    required this.medicationName,
    this.remainingPercent,
    this.taken = false,
  });

  factory DoseItem.fromScheduleJson(
    Map<String, dynamic> json,
    String medicationName,
    double? remainingPercent,
  ) {
    // 서버는 UTC로 내려줘("...Z"). 기기 타임존에 기대지 않고 한국 시간(UTC+9 고정)으로
    // 직접 바꾼 다음에 써야 아침/점심/저녁이 기기 설정과 무관하게 항상 올바르게 갈린다.
    final scheduledAt =
        toKoreaTime(DateTime.parse(json['scheduled_at'] as String));
    return DoseItem(
      id: json['id'] as String,
      date: scheduledAt,
      time: doseTimeFromHour(scheduledAt.hour),
      medicationName: medicationName,
      remainingPercent: remainingPercent,
      taken: json['is_taken'] as bool? ?? false,
    );
  }
}

class WeeklyAdherence {
  final List<bool> dayCompleted;
  const WeeklyAdherence({required this.dayCompleted});
  double get rate {
    if (dayCompleted.isEmpty) return 0;
    final doneCount = dayCompleted.where((d) => d).length;
    return doneCount / dayCompleted.length;
  }
}

class DailyDoseRecord {
  final DateTime date;
  final List<DoseItem> doses;
  const DailyDoseRecord({required this.date, required this.doses});
  bool get allTaken => doses.isNotEmpty && doses.every((d) => d.taken);
}
