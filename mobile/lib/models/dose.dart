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

<<<<<<< HEAD
=======
DoseTime doseTimeFromHour(int hour) {
  if (hour < 11) return DoseTime.morning;
  if (hour < 17) return DoseTime.lunch;
  return DoseTime.evening;
}

>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
class DoseItem {
  final String id;
  final DateTime date;
  final DoseTime time;
<<<<<<< HEAD
  final String medicationName; // 예: 혈압약, 소화제
  bool taken; // 복약기록 체크 여부
=======
  final String medicationName;
  final double? remainingPercent;
  bool taken;
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

  DoseItem({
    required this.id,
    required this.date,
    required this.time,
    required this.medicationName,
<<<<<<< HEAD
    this.taken = false,
  });
}

class WeeklyAdherence {
  final List<bool> dayCompleted; // 일~토 순서, 그날 복용 다 했는지

  const WeeklyAdherence({required this.dayCompleted});

=======
    this.remainingPercent,
    this.taken = false,
  });

  factory DoseItem.fromScheduleJson(
    Map<String, dynamic> json,
    String medicationName,
    double? remainingPercent,
  ) {
    final scheduledAt = DateTime.parse(json['scheduled_at'] as String);
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
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  double get rate {
    if (dayCompleted.isEmpty) return 0;
    final doneCount = dayCompleted.where((d) => d).length;
    return doneCount / dayCompleted.length;
  }
}

class DailyDoseRecord {
  final DateTime date;
  final List<DoseItem> doses;
<<<<<<< HEAD

  const DailyDoseRecord({required this.date, required this.doses});

=======
  const DailyDoseRecord({required this.date, required this.doses});
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  bool get allTaken => doses.isNotEmpty && doses.every((d) => d.taken);
}
