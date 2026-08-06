import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// 기기 기본 showTimePicker는 "Select time"/"AM"/"PM"/"Cancel" 등 전부 영어라서,
// 앱 전체(복용 알림 설정, 예약 일정 변경 등)에서 시간을 바꿀 땐 이 위젯을 대신 쓴다.
Future<TimeOfDay?> showKoreanTimeSheet(
  BuildContext context, {
  required TimeOfDay initialTime,
  String title = '시간 변경',
  String? subtitle,
  List<TimeOfDay> quickPicks = const [
    TimeOfDay(hour: 9, minute: 0),
    TimeOfDay(hour: 10, minute: 0),
    TimeOfDay(hour: 13, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 17, minute: 0),
  ],
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _KoreanTimeSheet(
      title: title,
      subtitle: subtitle,
      initialTime: initialTime,
      quickPicks: quickPicks,
    ),
  );
}

class _KoreanTimeSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final TimeOfDay initialTime;
  final List<TimeOfDay> quickPicks;

  const _KoreanTimeSheet({
    required this.title,
    required this.subtitle,
    required this.initialTime,
    required this.quickPicks,
  });

  @override
  State<_KoreanTimeSheet> createState() => _KoreanTimeSheetState();
}

class _KoreanTimeSheetState extends State<_KoreanTimeSheet> {
  static const _minutes = [0, 10, 20, 30, 40, 50];

  late int _hour;
  late int _minuteIndex;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    final idx = _minutes.indexWhere((m) => m >= widget.initialTime.minute);
    _minuteIndex = idx == -1 ? _minutes.length - 1 : idx;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minuteIndex);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  TimeOfDay get _currentTime =>
      TimeOfDay(hour: _hour, minute: _minutes[_minuteIndex]);

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _applyQuickPick(TimeOfDay t) {
    final minuteIndex = _minutes.indexOf(t.minute);
    setState(() {
      _hour = t.hour;
      _minuteIndex = minuteIndex == -1 ? 0 : minuteIndex;
    });
    _hourController.animateToItem(_hour,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    _minuteController.animateToItem(_minuteIndex,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _PreviewBox(
                    label: '변경 전',
                    subtitle: widget.subtitle,
                    time: _fmt(widget.initialTime),
                    emphasize: false,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: _PreviewBox(
                    label: '변경 중',
                    subtitle: widget.subtitle,
                    time: _fmt(_currentTime),
                    emphasize: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('시간 선택', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 140,
                      child: CupertinoPicker(
                        scrollController: _hourController,
                        itemExtent: 40,
                        onSelectedItemChanged: (i) => setState(() => _hour = i),
                        selectionOverlay: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        children: List.generate(
                            24,
                            (h) => Center(
                                child: Text(h.toString().padLeft(2, '0'),
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)))),
                      ),
                    ),
                  ),
                  const Text(':',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: SizedBox(
                      height: 140,
                      child: CupertinoPicker(
                        scrollController: _minuteController,
                        itemExtent: 40,
                        onSelectedItemChanged: (i) =>
                            setState(() => _minuteIndex = i),
                        selectionOverlay: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        children: _minutes
                            .map((m) => Center(
                                child: Text(m.toString().padLeft(2, '0'),
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold))))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('빠른 선택', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: widget.quickPicks.map((t) {
                final selected =
                    _currentTime.hour == t.hour && _currentTime.minute == t.minute;
                return OutlinedButton(
                  onPressed: () => _applyQuickPick(t),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selected ? colorScheme.primary : null,
                    foregroundColor:
                        selected ? Colors.white : colorScheme.onSurfaceVariant,
                    side: BorderSide(
                        color: selected ? colorScheme.primary : colorScheme.outline),
                  ),
                  child: Text(_fmt(t)),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_currentTime),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String time;
  final bool emphasize;

  const _PreviewBox({
    required this.label,
    required this.subtitle,
    required this.time,
    required this.emphasize,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasize
            ? colorScheme.primary.withOpacity(0.12)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: emphasize ? Border.all(color: colorScheme.primary) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
          Text(time,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: emphasize ? colorScheme.primary : null)),
        ],
      ),
    );
  }
}
