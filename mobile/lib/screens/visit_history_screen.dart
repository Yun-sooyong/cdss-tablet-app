import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/visit.dart';
import '../services/visit_service.dart';
import 'visit_detail.screen.dart';
import '../widgets/loading_spinner.dart';

class VisitHistoryScreen extends StatefulWidget {
  final VisitService visitService;
  const VisitHistoryScreen({super.key, required this.visitService});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  final _searchController = TextEditingController();
  VisitSearchField _field = VisitSearchField.memo;
  DateTime? _filterDate;
  List<Visit> _visits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final visits = await widget.visitService.fetchVisits(
      query: _searchController.text,
      field: _field,
      onDate: _filterDate,
    );
    if (!mounted) return;
    setState(() {
      _visits = visits;
      _isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final visitDates = await widget.visitService.fetchVisitDates();
    if (!mounted) return;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (_) => _VisitCalendarSheet(
          markedDates: visitDates, initialDate: _filterDate),
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
      _load();
    }
  }

  String _fieldLabel(VisitSearchField f) {
    switch (f) {
      case VisitSearchField.all:
        return '통합';
      case VisitSearchField.memo:
        return '병명';
      case VisitSearchField.department:
        return '진료과';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              PopupMenuButton<VisitSearchField>(
                icon: const Icon(Icons.filter_list),
                tooltip: '${_fieldLabel(_field)}로 검색 중',
                onSelected: (f) {
                  setState(() => _field = f);
                  _load();
                },
                itemBuilder: (context) => VisitSearchField.values
                    .map((f) => PopupMenuItem(
                        value: f, child: Text('${_fieldLabel(f)}로 검색')))
                    .toList(),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '${_fieldLabel(_field)} 검색',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                  tooltip: '날짜로 필터'),
              if (_filterDate != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _filterDate = null);
                    _load();
                  },
                ),
            ],
          ),
        ),
        if (_isLoading)
          const Expanded(child: Center(child: LoadingSpinner()))
        else if (_visits.isEmpty)
          const Expanded(
              child: Center(
                  child:
                      Text('진료 기록이 없어', style: TextStyle(color: Colors.grey))))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _visits.length,
              itemBuilder: (context, i) {
                final v = _visits[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(v.memo),
                    subtitle: Text(
                        '${v.department}${v.doctorName != null ? ' · ${v.doctorName}' : ''}'),
                    trailing: Text(
                      '${v.date.year}.${v.date.month.toString().padLeft(2, '0')}.${v.date.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => VisitDetailScreen(visit: v)),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _VisitCalendarSheet extends StatefulWidget {
  final Set<DateTime> markedDates;
  final DateTime? initialDate;

  const _VisitCalendarSheet({required this.markedDates, this.initialDate});

  @override
  State<_VisitCalendarSheet> createState() => _VisitCalendarSheetState();
}

class _VisitCalendarSheetState extends State<_VisitCalendarSheet> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate ?? DateTime.now();
    _selectedDay = widget.initialDate;
  }

  bool _hasVisit(DateTime day) {
    return widget.markedDates.any(
        (d) => d.year == day.year && d.month == day.month && d.day == day.day);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) =>
                _selectedDay != null && isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (!_hasVisit(day)) return null;
                return const Positioned(
                  bottom: 4,
                  child: Icon(Icons.circle, size: 6, color: Colors.redAccent),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _selectedDay == null
                ? null
                : () => Navigator.of(context).pop(_selectedDay),
            child: const Text('이 날짜로 검색'),
          ),
        ],
      ),
    );
  }
}
