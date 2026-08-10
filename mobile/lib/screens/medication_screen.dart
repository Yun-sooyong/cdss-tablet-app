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

  void _openHistory() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WeeklyMedicationHistoryScreen(
            medicationService: widget.medicationService)));
  }

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) {
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdayLabels[d.weekday - 1];
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} ($weekday)';
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
    final doneCount = _doses.where((d) => d.taken).length;
    final allTaken = _doses.isNotEmpty && doneCount == _doses.length;
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
              onTap: _openHistory,
              onOpenPrescriptions: _openPrescriptions,
            ),
          const SizedBox(height: 12),
          _TodayHeroCard(
            date: _fmtDate(DateTime.now()),
            allTaken: allTaken,
            hasDoses: _doses.isNotEmpty,
            nextDose: nextDose,
            fmtTime: _fmtTime,
            onOpenSettings: _openDoseTimeSettings,
          ),
          const SizedBox(height: 20),
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
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        doseTime == DoseTime.evening
                            ? Icons.nightlight_round
                            : Icons.wb_sunny_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(doseTime.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${group.length}개',
                            style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ),
                ...group.map((dose) =>
                    _DoseTile(dose: dose, onTaken: () => _toggleTaken(dose))),
                const SizedBox(height: 4),
              ];
            }),
          const SizedBox(height: 8),
          _ForgotReminderCard(onTap: _openHistory),
        ],
      ),
    );
  }
}

class _TodayHeroCard extends StatelessWidget {
  final String date;
  final bool allTaken;
  final bool hasDoses;
  final DoseItem? nextDose;
  final String Function(DateTime) fmtTime;
  final VoidCallback onOpenSettings;

  const _TodayHeroCard({
    required this.date,
    required this.allTaken,
    required this.hasDoses,
    required this.nextDose,
    required this.fmtTime,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headline = !hasDoses
        ? '오늘은 예정된\n복용이 없어요'
        : allTaken
            ? '오늘 복용을\n모두 마쳤어요'
            : '오늘 복용할\n약이 있어요';
    final subtitle = !hasDoses
        ? '새로운 처방이 등록되면 여기에 표시돼요.'
        : allTaken
            ? '수고하셨어요, 내일도 잊지 말고 챙겨주세요.'
            : nextDose != null
                ? '다음 복용 ${fmtTime(nextDose!.date)} · ${nextDose!.medicationName}'
                : '처방된 약을 꼭 챙겨 복용하세요.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -8,
            child: Icon(Icons.health_and_safety_outlined,
                size: 84, color: Colors.white.withOpacity(0.15)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.white,
                    child: Icon(
                      allTaken ? Icons.check : Icons.schedule,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(date,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_none,
                        color: Colors.white),
                    onPressed: onOpenSettings,
                    tooltip: '복용 알림 설정',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(headline,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3)),
              const SizedBox(height: 8),
              Text(subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.9))),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForgotReminderCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ForgotReminderCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primary.withOpacity(0.15),
            child: Icon(Icons.eco_outlined, color: colorScheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('복용을 잊으셨나요?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('기록을 확인하고 관리할 수 있어요.',
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: const Text('복용 기록 보기'),
          ),
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
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: dose.taken
                ? colorScheme.primary.withOpacity(0.15)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.medication_outlined,
            color: dose.taken ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: 22,
          ),
        ),
        title: Text(dose.medicationName),
        trailing: dose.taken
            ? Icon(Icons.check_circle, color: colorScheme.primary, size: 22)
            : Icon(Icons.radio_button_unchecked,
                color: colorScheme.onSurfaceVariant, size: 22),
      ),
    );
  }
}
