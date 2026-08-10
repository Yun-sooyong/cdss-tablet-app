import 'package:flutter/material.dart';
import '../models/dose.dart';
import '../services/medication_service.dart';
import '../widgets/loading_spinner.dart';

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
          ? const Center(child: LoadingSpinner())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length,
              itemBuilder: (context, i) {
                final record = _records[i];
                final colorScheme = Theme.of(context).colorScheme;
                final primary = colorScheme.primary;
                final label =
                    '${dayLabels[record.date.weekday % 7]}요일 · ${record.date.month}.${record.date.day}';
                if (record.doses.isEmpty) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(label,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('아직 기록 없음',
                          style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
                                  ? primary
                                  : colorScheme.onSurfaceVariant,
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
                                        ? primary
                                        : colorScheme.onSurfaceVariant,
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
