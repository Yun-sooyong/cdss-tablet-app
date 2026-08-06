import 'package:flutter/material.dart';
import '../models/dose.dart';
import '../services/notification_service.dart';
import '../widgets/korean_time_sheet.dart';
import '../widgets/loading_spinner.dart';

class DoseTimeSettingsScreen extends StatefulWidget {
  final NotificationService notificationService;
  final List<DoseItem> doses;

  const DoseTimeSettingsScreen({
    super.key,
    required this.notificationService,
    required this.doses,
  });

  @override
  State<DoseTimeSettingsScreen> createState() => _DoseTimeSettingsScreenState();
}

class _DoseTimeSettingsScreenState extends State<DoseTimeSettingsScreen> {
  List<MedicationReminderGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups =
        await widget.notificationService.loadReminderGroups(widget.doses);
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  Future<void> _toggleSlot(
      String medicationName, DoseTimeSlotSetting slot, bool value) async {
    await widget.notificationService
        .setSlotEnabled(medicationName, slot.time, value);
    if (!mounted) return;
    setState(() => slot.enabled = value);
  }

  Future<void> _pickTime(
      String medicationName, DoseTimeSlotSetting slot) async {
    final picked = await showKoreanTimeSheet(
      context,
      initialTime: slot.timeOfDay,
      subtitle: slot.time.label,
      quickPicks: const [
        TimeOfDay(hour: 7, minute: 0),
        TimeOfDay(hour: 18, minute: 0),
        TimeOfDay(hour: 19, minute: 0),
        TimeOfDay(hour: 20, minute: 0),
        TimeOfDay(hour: 21, minute: 0),
        TimeOfDay(hour: 22, minute: 0),
      ],
    );
    if (picked == null) return;
    await widget.notificationService
        .saveDoseTimeFor(medicationName, slot.time, picked);
    if (!mounted) return;
    setState(() => slot.timeOfDay = picked);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('복용 알림 설정')),
      body: _isLoading
          ? const Center(child: LoadingSpinner())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Column(
                  children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            child: Icon(Icons.notifications_active_outlined,
                                size: 36, color: colorScheme.primary),
                          ),
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: colorScheme.primary,
                              child: const Icon(Icons.eco,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('정해진 시간에 복용 알림을 보내드려요',
                        style:
                            TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '규칙적인 복용이 치료 효과를 높여줍니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('오늘 등록된 복용 약이 없어요',
                        style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  )
                else
                  ..._groups.map((group) => Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    child: Icon(Icons.medication_outlined,
                                        size: 18, color: colorScheme.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(group.medicationName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        Text('1일 ${group.slots.length}회',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    colorScheme.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              ...group.slots.map((slot) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: slot.enabled
                                          ? () => _pickTime(
                                              group.medicationName, slot)
                                          : null,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: colorScheme
                                                  .surfaceContainerHighest,
                                              child: Icon(
                                                slot.time == DoseTime.evening
                                                    ? Icons.nightlight_round
                                                    : Icons.wb_sunny_outlined,
                                                size: 16,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(slot.time.label,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: colorScheme
                                                              .onSurfaceVariant)),
                                                  Text(_fmt(slot.timeOfDay),
                                                      style: const TextStyle(
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                            Switch(
                                              value: slot.enabled,
                                              onChanged: (v) => _toggleSlot(
                                                  group.medicationName, slot, v),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      )),
              ],
            ),
    );
  }
}
