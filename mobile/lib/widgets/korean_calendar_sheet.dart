import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

// table_calendar 기본 위젯은 월/요일 표시가 영어라서, 앱 어디서 캘린더를 띄우든
// 이 위젯을 통해 한국어(년/월, 일~토)로 통일해서 보여준다.
Future<DateTime?> showKoreanCalendarSheet(
  BuildContext context, {
  required DateTime firstDay,
  required DateTime lastDay,
  DateTime? initialDate,
  Set<DateTime> markedDates = const {},
  String confirmLabel = '확인',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _KoreanCalendarSheet(
      firstDay: firstDay,
      lastDay: lastDay,
      initialDate: initialDate,
      markedDates: markedDates,
      confirmLabel: confirmLabel,
    ),
  );
}

class _KoreanCalendarSheet extends StatefulWidget {
  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime? initialDate;
  final Set<DateTime> markedDates;
  final String confirmLabel;

  const _KoreanCalendarSheet({
    required this.firstDay,
    required this.lastDay,
    required this.initialDate,
    required this.markedDates,
    required this.confirmLabel,
  });

  @override
  State<_KoreanCalendarSheet> createState() => _KoreanCalendarSheetState();
}

class _KoreanCalendarSheetState extends State<_KoreanCalendarSheet> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _focusedDay = initial.isBefore(widget.firstDay) ? widget.firstDay : initial;
    _selectedDay = widget.initialDate;
  }

  bool _isMarked(DateTime day) {
    return widget.markedDates.any(
        (d) => d.year == day.year && d.month == day.month && d.day == day.day);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TableCalendar(
              firstDay: widget.firstDay,
              lastDay: widget.lastDay,
              focusedDay: _focusedDay,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextFormatter: (date, locale) =>
                    '${date.year}년 ${date.month}월',
              ),
              daysOfWeekHeight: 24,
              selectedDayPredicate: (day) =>
                  _selectedDay != null && isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              calendarBuilders: CalendarBuilders(
                dowBuilder: (context, day) {
                  const labels = ['일', '월', '화', '수', '목', '금', '토'];
                  final label = labels[day.weekday % 7];
                  Color? color;
                  if (day.weekday == DateTime.sunday) {
                    color = colorScheme.error;
                  } else if (day.weekday == DateTime.saturday) {
                    color = colorScheme.primary;
                  }
                  return Center(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  );
                },
                markerBuilder: widget.markedDates.isEmpty
                    ? null
                    : (context, day, events) {
                        if (!_isMarked(day)) return null;
                        return const Positioned(
                          bottom: 4,
                          child:
                              Icon(Icons.circle, size: 6, color: Colors.redAccent),
                        );
                      },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedDay == null
                    ? null
                    : () => Navigator.of(context).pop(_selectedDay),
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
