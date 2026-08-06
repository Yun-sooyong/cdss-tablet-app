import 'package:flutter/material.dart';
import '../models/dose.dart';
import '../services/notification_service.dart';
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
    final picked =
        await showTimePicker(context: context, initialTime: slot.timeOfDay);
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
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.notifications_active_outlined,
                          size: 36, color: colorScheme.primary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '약 복용 시간을 설정하면\n시간에 맞춰 알림을 보내드려요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
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
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(slot.time.label,
                                              style: const TextStyle(
                                                  fontSize: 15)),
                                        ),
                                        TextButton(
                                          onPressed: slot.enabled
                                              ? () => _pickTime(
                                                  group.medicationName, slot)
                                              : null,
                                          child: Text(_fmt(slot.timeOfDay)),
                                        ),
                                        Switch(
                                          value: slot.enabled,
                                          onChanged: (v) => _toggleSlot(
                                              group.medicationName, slot, v),
                                        ),
                                      ],
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
