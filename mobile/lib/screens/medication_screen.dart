import 'package:flutter/material.dart';
import '../models/dose.dart';
import '../services/medication_service.dart';
import '../theme/app_colors.dart';
import 'weekly_medication_history_screen.dart';
import '../services/notification_service.dart';

class MedicationScreen extends StatefulWidget {
  final MedicationService medicationService;
  final NotificationService notificationService;

  const MedicationScreen(
      {super.key,
      required this.medicationService,
      required this.notificationService});
  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  WeeklyAdherence? _adherence;
  List<DoseItem> _doses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openDoseTimeSettings() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DoseTimeSettingsSheet(
          notificationService: widget.notificationService),
    );
    if (saved == true) {
      await widget.notificationService.scheduleDailyDoseReminders(_doses);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 시간이 변경되었습니다.')),
      );
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final adherenceFuture = widget.medicationService.fetchWeeklyAdherence();
    final dosesFuture = widget.medicationService.fetchTodayDoses();

    final adherence = await adherenceFuture;
    final doses = await dosesFuture;
    if (!mounted) return;
    setState(() {
      _adherence = adherence;
      _doses = doses;
      _isLoading = false;
    });
    await widget.notificationService.scheduleDailyDoseReminders(_doses);
  }

  Future<void> _markTaken(DoseItem dose) async {
    await widget.medicationService.markTaken(dose.id);
    setState(() => dose.taken = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${now.year}년 ${now.month}월',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_adherence != null)
            _AdherenceCard(
                adherence: _adherence!,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WeeklyMedicationHistoryScreen(
                        medicationService: widget.medicationService)))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('오늘 복용',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('알림 설정'),
                onPressed: _openDoseTimeSettings,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._doses.map(
              (dose) => _DoseTile(dose: dose, onTaken: () => _markTaken(dose))),
        ],
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  final WeeklyAdherence adherence;
  final VoidCallback onTap;

  const _AdherenceCard({required this.adherence, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final percent = (adherence.rate * 100).round();
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('이번 주 복약률 $percent%',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final done = i < adherence.dayCompleted.length &&
                      adherence.dayCompleted[i];
                  return Column(
                    children: [
                      Text(days[i],
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      CircleAvatar(
                        radius: 10,
                        backgroundColor:
                            done ? AppColors.primary : Colors.grey.shade300,
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoseTile extends StatelessWidget {
  final DoseItem dose;
  final VoidCallback onTaken;

  const _DoseTile({required this.dose, required this.onTaken});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          dose.taken ? Icons.check_circle : Icons.circle_outlined,
          color: dose.taken ? AppColors.primary : Colors.grey,
        ),
        title: Text(dose.medicationName),
        subtitle: Text(dose.time.label),
        trailing: dose.taken
            ? const Text('복용완료', style: TextStyle(color: Colors.grey))
            : TextButton(onPressed: onTaken, child: const Text('복용완료')),
      ),
    );
  }
}

class _DoseTimeSettingsSheet extends StatefulWidget {
  final NotificationService notificationService;

  const _DoseTimeSettingsSheet({required this.notificationService});

  @override
  State<_DoseTimeSettingsSheet> createState() => _DoseTimeSettingsSheetState();
}

class _DoseTimeSettingsSheetState extends State<_DoseTimeSettingsSheet> {
  Map<DoseTime, TimeOfDay> _times = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final times = await widget.notificationService.loadDoseTimes();
    if (!mounted) return;
    setState(() {
      _times = times;
      _isLoading = false;
    });
  }

  Future<void> _pickTime(DoseTime doseTime) async {
    final current = _times[doseTime] ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    setState(() => _times[doseTime] = picked);
  }

  Future<void> _save() async {
    for (final entry in _times.entries) {
      await widget.notificationService.saveDoseTime(entry.key, entry.value);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('알림 시간 설정',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...DoseTime.values.map((doseTime) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(doseTime.label),
                      trailing: OutlinedButton(
                        onPressed: () => _pickTime(doseTime),
                        child: Text(_fmt(_times[doseTime] ??
                            const TimeOfDay(hour: 9, minute: 0))),
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
    );
  }
}
