import '../models/dose.dart';

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
    await Future.delayed(const Duration(milliseconds: 300));
    return WeeklyAdherence(
      weekStart: DateTime.now(),
      rate: 0.8,
      dayCompleted: [true, false, false, false, false, false, false],
    );
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
}
