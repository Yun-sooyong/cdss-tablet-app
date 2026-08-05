import 'package:flutter/material.dart';
import '../models/dose.dart';
import '../services/medication_service.dart';
import '../theme/app_colors.dart';
<<<<<<< HEAD
=======
import '../widgets/loading_spinner.dart';
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

class WeeklyMedicationHistoryScreen extends StatefulWidget {
  final MedicationService medicationService;

  const WeeklyMedicationHistoryScreen(
      {super.key, required this.medicationService});

  @override
  State<WeeklyMedicationHistoryScreen> createState() =>
      _WeeklyMedicationHistoryScreenState();
}

class _WeeklyMedicationHistoryScreenState
    extends State<WeeklyMedicationHistoryScreen> {
  List<DailyDoseRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await widget.medicationService.fetchWeeklyDoseHistory();
    if (!mounted) return;
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['일', '월', '화', '수', '목', '금', '토'];
    return Scaffold(
      appBar: AppBar(title: const Text('이번 주 복약 기록')),
      body: _isLoading
<<<<<<< HEAD
          ? const Center(child: CircularProgressIndicator())
=======
          ? const Center(child: LoadingSpinner())
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length,
              itemBuilder: (context, i) {
                final record = _records[i];
                final label =
                    '${dayLabels[record.date.weekday % 7]}요일 · ${record.date.month}.${record.date.day}';
                if (record.doses.isEmpty) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(label,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('아직 기록 없음',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              record.allTaken
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: record.allTaken
                                  ? AppColors.primary
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...record.doses.map((d) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    d.taken ? Icons.check : Icons.close,
                                    size: 16,
                                    color: d.taken
                                        ? AppColors.primary
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('${d.time.label} · ${d.medicationName}'),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
