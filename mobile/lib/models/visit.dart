class Diagnosis {
  final String nameKo;
  final bool isPrimary;
  Diagnosis({required this.nameKo, required this.isPrimary});
  factory Diagnosis.fromJson(Map<String, dynamic> json) {
    final disease = json['disease'] as Map<String, dynamic>;
    return Diagnosis(
      nameKo: disease['name_ko'] as String,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

class Visit {
  final String id;
  final DateTime date;
  final String department;
  final String memo; // 목록 화면 검색·표시용 (진단명 우선, 없으면 note)
  final String note; // 의료진이 남긴 원본 메모 — 상세화면에서 항상 이걸 보여줌
  final String? doctorName;
  final List<Diagnosis> diagnoses;

  Visit({
    required this.id,
    required this.date,
    required this.department,
    required this.memo,
    required this.note,
    this.doctorName,
    this.diagnoses = const [],
  });

  factory Visit.fromJson(Map<String, dynamic> json) {
    final diagnosesJson = json['diagnoses'] as List<dynamic>? ?? [];
    final diagnoses = diagnosesJson
        .map((d) => Diagnosis.fromJson(d as Map<String, dynamic>))
        .toList();
    final note = json['note'] as String? ?? '';
    final memo = diagnoses.isNotEmpty
        ? diagnoses.map((d) => d.nameKo).join(', ')
        : (note.isNotEmpty ? note : '진료 기록');
    return Visit(
      id: json['id'] as String,
      date: DateTime.parse(json['visited_at'] as String),
      department: json['department'] as String? ?? '',
      memo: memo,
      note: note,
      diagnoses: diagnoses,
    );
  }
}
