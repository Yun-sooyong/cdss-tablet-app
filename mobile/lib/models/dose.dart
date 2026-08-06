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
    // 서버는 UTC로 내려줘("...Z"). .hour를 바로 읽으면 UTC 기준 시간으로 아침/점심/저녁을
    // 나눠버리게 되니까, 파싱하자마자 .toLocal()로 한국 시간으로 바꾼 다음에 써야 해.
    final scheduledAt =
        DateTime.parse(json['scheduled_at'] as String).toLocal();
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
