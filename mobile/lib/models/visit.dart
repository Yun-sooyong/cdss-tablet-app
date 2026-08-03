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
  final DateTime weekStart;
  final double rate; // 0.0 ~ 1.0
  final List<bool> dayCompleted; // 주간 캘린더 점 표시용 (일~토 7칸)

  WeeklyAdherence({
    required this.weekStart,
    required this.rate,
    required this.dayCompleted,
  });
}
