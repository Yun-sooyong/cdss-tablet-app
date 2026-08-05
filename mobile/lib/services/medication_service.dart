<<<<<<< HEAD
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
=======
import 'dart:convert';
import '../models/dose.dart';
import '../models/prescription.dart';
import 'api_client.dart';

class MedicationService {
  final _client = ApiClient.instance;

  Future<List<DoseItem>> _fetchAllDoses({DateTime? from, DateTime? to}) async {
    final query = <String, String>{};
    if (from != null) query['from'] = from.toIso8601String();
    if (to != null) query['to'] = to.toIso8601String();

    final res = await _client.get(
      '/api/v1/patients/me/medications/schedule/',
      query: query.isEmpty ? null : query,
    );
    if (res.statusCode != 200) {
      throw Exception('복약 스케줄을 불러오지 못했어요.');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    final doses = <DoseItem>[];
    for (final group in data) {
      final drugName = group['drug']['product_name'] as String;
      final remainingPercent = (group['remaining_percent'] as num?)?.toDouble();
      final schedules = group['schedules'] as List<dynamic>;
      for (final s in schedules) {
        doses.add(DoseItem.fromScheduleJson(
          s as Map<String, dynamic>,
          drugName,
          remainingPercent,
        ));
      }
    }
    doses.sort((a, b) => a.date.compareTo(b.date));
    return doses;
  }

  Future<List<DoseItem>> fetchTodayDoses() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _fetchAllDoses(from: startOfDay, to: endOfDay);
  }

  Future<void> markTaken(String doseId) async {
    final res = await _client.post('/api/v1/medications/logs/', body: {
      'schedule_id': doseId,
    });
    if (res.statusCode != 201) {
      throw Exception('복용 체크에 실패했어요.');
    }
  }

  Future<List<DailyDoseRecord>> fetchWeeklyDoseHistory() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: now.weekday % 7));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final allDoses = await _fetchAllDoses(from: startOfWeek, to: endOfWeek);

    final records = <DailyDoseRecord>[];
    for (var i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dosesForDay = allDoses
          .where((d) =>
              d.date.year == date.year &&
              d.date.month == date.month &&
              d.date.day == date.day)
          .toList();
      records.add(DailyDoseRecord(date: date, doses: dosesForDay));
    }
    return records;
  }
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

  Future<WeeklyAdherence> fetchWeeklyAdherence() async {
    final history = await fetchWeeklyDoseHistory();
    return WeeklyAdherence(
        dayCompleted: history.map((r) => r.allTaken).toList());
  }

<<<<<<< HEAD
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
=======
  Future<List<Prescription>> fetchPrescriptions() async {
    final res = await _client.get('/api/v1/patients/me/prescriptions/');
    if (res.statusCode != 200) {
      throw Exception('처방내역을 불러오지 못했어요.');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((p) => Prescription.fromJson(p as Map<String, dynamic>)).toList();
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  }
}
