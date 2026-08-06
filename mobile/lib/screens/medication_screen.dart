import 'package:flutter/material.dart';
import '../models/dose.dart';
import '../services/medication_service.dart';
import 'weekly_medication_history_screen.dart';
import '../services/notification_service.dart';
import '../utils/top_banner.dart';
import '../widgets/loading_spinner.dart';
import 'prescription_info_screen.dart';
import 'dose_time_settings_screen.dart';

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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoseTimeSettingsScreen(
          notificationService: widget.notificationService,
          doses: _doses,
        ),
      ),
    );
    // 설정 화면 안에서 바뀔 때마다 이미 바로 저장됐으니, 나왔을 때 최신 값으로 알림만 다시 걸면 됨.
    await widget.notificationService.scheduleDailyDoseReminders(_doses);
    if (!mounted) return;
    showTopBanner(context, '알림 설정이 반영되었어요.');
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

    final colorScheme = Theme.of(context).colorScheme;
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
                        Text('다음 복용',
                            style: TextStyle(
                                fontSize: 13, color: colorScheme.onSurfaceVariant)),
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
          if (_doses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('오늘 복용할 약이 없어요',
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
            )
          else
            ...DoseTime.values.expand((doseTime) {
              final group = _doses.where((d) => d.time == doseTime).toList();
              if (group.isEmpty) return <Widget>[];
              return [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(doseTime.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant)),
                ),
                ...group.map((dose) =>
                    _DoseTile(dose: dose, onTaken: () => _toggleTaken(dose))),
              ];
            }),
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
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
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
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(primary),
                            ),
                          ),
                          Text('$percent%',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        '이번 주 복약률', // 목업엔 '이번 달'이지만 실데이터가 주간(WeeklyAdherence)이라 정직하게 뒀어
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined,
                          color: primary, size: 18),
                      const SizedBox(width: 6),
                      const Flexible(
                          child:
                              Text('처방 내역', overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.chevron_right, size: 18),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTaken,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: dose.taken
              ? colorScheme.primary.withOpacity(0.15)
              : colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.medication_outlined,
            color: dose.taken ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Text(dose.medicationName),
        trailing: dose.taken
            ? Icon(Icons.check_circle, color: colorScheme.primary, size: 20)
            : Icon(Icons.schedule, color: colorScheme.onSurfaceVariant, size: 20),
      ),
    );
  }
}
