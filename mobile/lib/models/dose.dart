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

class DoseItem {
  final String id;
  final DateTime date;
  final DoseTime time;
  final String medicationName; // 예: 혈압약, 소화제
  bool taken; // 복약기록 체크 여부

  DoseItem({
    required this.id,
    required this.date,
    required this.time,
    required this.medicationName,
    this.taken = false,
  });
}

class WeeklyAdherence {
  final List<bool> dayCompleted; // 일~토 순서, 그날 복용 다 했는지

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
