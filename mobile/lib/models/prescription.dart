class Prescription {
  final String medicationName;
  final String dosageInfo; // 예: "1일 2회 · 아침·저녁 식후 30분"
  final String description; // 약 설명
  final DateTime prescribedDate;

  const Prescription({
    required this.medicationName,
    required this.dosageInfo,
    required this.description,
    required this.prescribedDate,
  });
}
