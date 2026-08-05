class PrescribedDrug {
  final String productName;
  final String unit;
  final double dosePerTake;
  final int timesPerDay;
  final int totalDays;

  PrescribedDrug({
    required this.productName,
    required this.unit,
    required this.dosePerTake,
    required this.timesPerDay,
    required this.totalDays,
  });

  factory PrescribedDrug.fromJson(Map<String, dynamic> json) {
    final drug = json['drug'] as Map<String, dynamic>;
    return PrescribedDrug(
      productName: drug['product_name'] as String,
      unit: drug['unit'] as String,
      dosePerTake: (json['dose_per_take'] as num).toDouble(),
      timesPerDay: json['times_per_day'] as int,
      totalDays: json['total_days'] as int,
    );
  }

  String get dosageInfo =>
      '1회 $dosePerTake$unit · 1일 $timesPerDay회 · $totalDays일분';
}

class Prescription {
  final String id;
  final DateTime prescribedDate;
  final String? fileUrl;
  final List<PrescribedDrug> drugs;

  Prescription({
    required this.id,
    required this.prescribedDate,
    this.fileUrl,
    required this.drugs,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      id: json['id'] as String,
      prescribedDate: DateTime.parse(json['prescribed_at'] as String),
      fileUrl: json['file_url'] as String?,
      drugs: (json['drugs'] as List<dynamic>)
          .map((d) => PrescribedDrug.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}
