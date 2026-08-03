import '../models/dose.dart';
import '../models/prescription.dart';

class MedicationService {
  final List<DoseItem> _today = [
    DoseItem(
      id: 'd1',
      date: DateTime.now(),
      time: DoseTime.morning,
      medicationName: '혈압약',
      taken: true,
    ),
    DoseItem(
      id: 'd2',
      date: DateTime.now(),
      time: DoseTime.lunch,
      medicationName: '소화제',
    ),
    DoseItem(
      id: 'd3',
      date: DateTime.now(),
      time: DoseTime.evening,
      medicationName: '혈압약',
    ),
  ];

  Future<WeeklyAdherence> fetchWeeklyAdherence() async {
    final history = await fetchWeeklyDoseHistory();
    return WeeklyAdherence(
        dayCompleted: history.map((r) => r.allTaken).toList());
  }

  Future<List<DoseItem>> fetchTodayDoses() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_today);
  }

  Future<void> markTaken(String doseId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final dose = _today.where((d) => d.id == doseId);
    if (dose.isNotEmpty) dose.first.taken = true;
  }

  Future<List<Prescription>> fetchPrescriptions() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Prescription(
        medicationName: '혈압약',
        dosageInfo: '1일 2회 · 아침·저녁 식후 30분',
        description: '혈압을 낮춰주는 약이에요. 어지럽거나 부종이 심해지면 병원에 문의하세요.',
        prescribedDate: DateTime(2026, 7, 20),
      ),
      Prescription(
        medicationName: '소화제',
        dosageInfo: '1일 1회 · 점심 식후',
        description: '소화 불량, 속쓰림 완화를 도와주는 약이에요.',
        prescribedDate: DateTime(2026, 7, 20),
      ),
    ];
  }

  // 이번 주(일~토) 요일별 복약 기록 — 카드에 나오는 퍼센트·점, 상세 기록 화면이
  // 전부 여기 하나에서만 데이터를 가져간다. 소스가 하나니까 서로 어긋날 수가 없다.
  Future<List<DailyDoseRecord>> fetchWeeklyDoseHistory() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek =
        today.subtract(Duration(days: now.weekday % 7)); // 일요일부터 시작

    final records = <DailyDoseRecord>[];
    for (var i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      if (date.isAfter(today)) {
        records.add(DailyDoseRecord(date: date, doses: const []));
      } else if (date == today) {
        records
            .add(DailyDoseRecord(date: date, doses: await fetchTodayDoses()));
      } else {
        final done = date.weekday != DateTime.friday; // 목데이터: 금요일만 미완료였다고 가정
        records.add(DailyDoseRecord(
          date: date,
          doses: [
            DoseItem(
                id: '${date.day}-1',
                date: date,
                medicationName: '혈압약',
                time: DoseTime.morning,
                taken: done),
            DoseItem(
                id: '${date.day}-2',
                date: date,
                medicationName: '소화제',
                time: DoseTime.lunch,
                taken: done),
            DoseItem(
                id: '${date.day}-3',
                date: date,
                medicationName: '혈압약',
                time: DoseTime.evening,
                taken: done),
          ],
        ));
      }
    }
    return records;
  }
}
