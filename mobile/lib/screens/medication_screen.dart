import 'package:flutter/material.dart';
import '../models/dose.dart';
import '../services/medication_service.dart';
import '../theme/app_colors.dart';
import 'weekly_medication_history_screen.dart';
import '../services/notification_service.dart';
import '../utils/top_banner.dart';
import '../widgets/loading_spinner.dart';
import 'prescription_info_screen.dart';

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
      showTopBanner(context, '알림 시간이 변경되었습니다.');
    }
  }

  void _openPrescriptions() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PrescriptionInfoScreen(
            medicationService: widget.medicationService)));
  }

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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

  Future<void> _toggleTaken(DoseItem dose) async {
    if (dose.taken) {
      await widget.medicationService.unmarkTaken(dose.id);
      if (!mounted) return;
      setState(() => dose.taken = false);
    } else {
      await widget.medicationService.markTaken(dose.id);
      if (!mounted) return;
      setState(() => dose.taken = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: LoadingSpinner());
    }

    final DoseItem? nextDose = _doses.where((d) => !d.taken).isNotEmpty
        ? _doses.firstWhere((d) => !d.taken)
        : null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_adherence != null)
            _AdherenceCard(
              adherence: _adherence!,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => WeeklyMedicationHistoryScreen(
                      medicationService: widget.medicationService))),
              onOpenPrescriptions: _openPrescriptions,
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('다음 복용',
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(
                            nextDose != null
                                ? _fmtTime(nextDose.date)
                                : '오늘 복용 완료',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        if (nextDose != null) ...[
                          const SizedBox(height: 2),
                          Text(nextDose.medicationName,
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.notifications_none, size: 18),
                    label: const Text('복용 알림 설정'),
                    onPressed: _openDoseTimeSettings,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('오늘 복용',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._doses.map((dose) =>
              _DoseTile(dose: dose, onTaken: () => _toggleTaken(dose))),
        ],
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  final WeeklyAdherence adherence;
  final VoidCallback onTap;
  final VoidCallback onOpenPrescriptions;

  const _AdherenceCard(
      {required this.adherence,
      required this.onTap,
      required this.onOpenPrescriptions});

  @override
  Widget build(BuildContext context) {
    final percent = (adherence.rate * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: CircularProgressIndicator(
                              value: adherence.rate,
                              strokeWidth: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.primary),
                            ),
                          ),
                          Text('$percent%',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                        '이번 주 복약률', // 목업엔 '이번 달'이지만 실데이터가 주간(WeeklyAdherence)이라 정직하게 뒀어
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            Container(
                width: 1,
                height: 100,
                color: Theme.of(context).dividerColor,
                margin: const EdgeInsets.symmetric(horizontal: 12)),
            Expanded(
              child: InkWell(
                onTap: onOpenPrescriptions,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined,
                          color: AppColors.primary, size: 18),
                      SizedBox(width: 6),
                      Flexible(
                          child:
                              Text('처방 내역', overflow: TextOverflow.ellipsis)),
                      Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
        onTap: onTaken,
        leading: Icon(
          dose.taken ? Icons.check_circle : Icons.circle_outlined,
          color: dose.taken ? AppColors.primary : Colors.grey,
        ),
        title: Text('${dose.time.label} · ${dose.medicationName}'),
        trailing: dose.taken
            ? const Text('복용완료',
                style: TextStyle(color: Colors.grey, fontSize: 12))
            : null,
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
              height: 120, child: Center(child: LoadingSpinner(size: 36)))
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
