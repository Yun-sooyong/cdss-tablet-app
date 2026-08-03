class Visit {
  final String id;
  final DateTime date;
  final String department;
  final String memo; // 병명/진료 사유
  final String? doctorName;

  Visit({
    required this.id,
    required this.date,
    required this.department,
    required this.memo,
    this.doctorName,
  });
}
