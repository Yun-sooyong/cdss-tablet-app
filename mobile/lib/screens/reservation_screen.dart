import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../services/visit_service.dart';
import '../utils/top_banner.dart';
import '../widgets/loading_spinner.dart';
import 'new_reservation_screen.dart';

String? _visitTypeLabel(String purpose) {
  if (purpose.contains('초진')) return '초진';
  if (purpose.contains('재진')) return '재진';
  return null;
}

class ReservationScreen extends StatefulWidget {
  final ReservationService reservationService;
  final VisitService visitService;
  const ReservationScreen(
      {super.key,
      required this.reservationService,
      required this.visitService});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  List<Reservation> _upcoming = [];
  List<Reservation> _past = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final upcomingFuture = widget.reservationService.fetchUpcoming();
    final pastFuture = widget.reservationService.fetchPast();
    final upcoming = await upcomingFuture;
    final past = await pastFuture;
    if (!mounted) return;
    setState(() {
      _upcoming = upcoming;
      _past = past;
      _isLoading = false;
    });
  }

  Future<void> _cancel(Reservation r) async {
    await widget.reservationService.cancel(r.id);
    _load();
  }

  Future<DateTime?> _pickDateTime({DateTime? initial}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime:
          initial != null ? TimeOfDay.fromDateTime(initial) : TimeOfDay.now(),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _reschedule(Reservation r) async {
    final newDate = await _pickDateTime(initial: r.dateTime);
    if (newDate == null) return;
    final reason = await _pickChangeReason();
    await widget.reservationService
        .reschedule(r.id, newDate, changeReason: reason);
    _load();
  }

  Future<String?> _pickChangeReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('일정 변경 사유 (선택)'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(hintText: '사유를 입력해줘 (안 써도 돼)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('건너뛰기'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(
                controller.text.trim().isEmpty ? null : controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _openNewReservation() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewReservationScreen(
          reservationService: widget.reservationService,
          visitService: widget.visitService,
        ),
      ),
    );
    if (created == true) {
      if (!mounted) return;
      showTopBanner(context, '예약 요청이 완료되었습니다.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: LoadingSpinner());
    }

    final colorScheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('다가오는 예약',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_upcoming.isEmpty)
            Text('다가오는 예약이 없어',
                style: TextStyle(color: colorScheme.onSurfaceVariant))
          else
            ..._upcoming.map((r) => _UpcomingCard(
                  reservation: r,
                  onReschedule: () => _reschedule(r),
                  onCancel: () => _cancel(r),
                )),
          const SizedBox(height: 24),
          const Text('지난 예약',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_past.isEmpty)
            Text('지난 예약이 없어',
                style: TextStyle(color: colorScheme.onSurfaceVariant))
          else
            ..._past.map((r) {
              const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
              final weekday = weekdayLabels[r.dateTime.weekday - 1];
              final visitLabel = _visitTypeLabel(r.purpose);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                      '${r.dateTime.month.toString().padLeft(2, '0')}.${r.dateTime.day.toString().padLeft(2, '0')} ($weekday) ${r.dateTime.hour.toString().padLeft(2, '0')}:${r.dateTime.minute.toString().padLeft(2, '0')}'),
                  subtitle: Text(
                      '${r.hospitalName} · ${r.department}${r.doctorName.isNotEmpty ? ' · ${r.doctorName}' : ''}${visitLabel != null ? ' · $visitLabel' : ''}'),
                ),
              );
            }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _openNewReservation,
              icon: const Icon(Icons.add),
              label: const Text('새 예약'),
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: BorderSide(color: colorScheme.primary),
                foregroundColor: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;

  const _UpcomingCard(
      {required this.reservation,
      required this.onReschedule,
      required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final d = reservation.dateTime;
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdayLabels[d.weekday - 1];
    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${d.month}.${d.day.toString().padLeft(2, '0')} ($weekday) ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${reservation.hospitalName} · ${reservation.department} · ${reservation.doctorName}',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: onReschedule, child: const Text('일정 수정'))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton(
                        onPressed: onCancel, child: const Text('예약 취소'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
