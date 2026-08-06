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
    final rawDose = json['dose_per_take'];
    final dosePerTake =
        rawDose is String ? double.parse(rawDose) : (rawDose as num).toDouble();
    final rawRemaining = json['remaining_percent'];
    final remainingPercent = rawRemaining == null
        ? null
        : (rawRemaining is String
            ? double.parse(rawRemaining)
            : (rawRemaining as num).toDouble());
    return PrescribedDrug(
      productName: drug['product_name'] as String,
      unit: drug['unit'] as String,
      dosePerTake: dosePerTake,
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
