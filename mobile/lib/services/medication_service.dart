import 'dart:convert';
import '../models/dose.dart';
import '../models/prescription.dart';
import 'api_client.dart';

class MedicationService {
  final _client = ApiClient.instance;

  Future<List<DoseItem>> _fetchAllDoses({DateTime? from, DateTime? to}) async {
    final query = <String, String>{};
    if (from != null) query['from'] = from.toUtc().toIso8601String();
    if (to != null) query['to'] = to.toUtc().toIso8601String();

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
      final rawRemaining = group['remaining_percent'];
      final remainingPercent = rawRemaining == null
          ? null
          : (rawRemaining is String
              ? double.parse(rawRemaining)
              : (rawRemaining as num).toDouble());
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

  Future<void> unmarkTaken(String doseId) async {
    final res = await _client.delete('/api/v1/medications/logs/$doseId/');
    if (res.statusCode != 204) {
      throw Exception('복용 취소에 실패했어요.');
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

  Future<WeeklyAdherence> fetchWeeklyAdherence() async {
    final history = await fetchWeeklyDoseHistory();
    return WeeklyAdherence(
        dayCompleted: history.map((r) => r.allTaken).toList());
  }

  Future<List<Prescription>> fetchPrescriptions() async {
    final res = await _client.get('/api/v1/patients/me/prescriptions/');
    if (res.statusCode != 200) {
      throw Exception('처방내역을 불러오지 못했어요.');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((p) => Prescription.fromJson(p as Map<String, dynamic>))
        .toList();
  }
}
