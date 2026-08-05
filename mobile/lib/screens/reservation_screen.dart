import 'package:flutter/material.dart';
<<<<<<< HEAD
=======
import '../models/department.dart';
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../services/visit_service.dart';
import '../theme/app_colors.dart';
import '../models/visit.dart';
<<<<<<< HEAD
=======
import '../utils/top_banner.dart';
import '../widgets/loading_spinner.dart';
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

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
<<<<<<< HEAD
    await widget.reservationService.reschedule(r.id, newDate);
    _load();
  }

=======
    final reason = await _pickChangeReason();
    await widget.reservationService.reschedule(r.id, newDate, changeReason: reason);
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

>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  void _showNewReservationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewReservationSheet(
        reservationService: widget.reservationService,
        visitService: widget.visitService,
<<<<<<< HEAD
        onSubmit: (dateTime, department, doctor, purpose) async {
=======
        onSubmit: (dateTime, department, purpose) async {
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
          await widget.reservationService.requestNew(
            dateTime: dateTime,
            hospitalName: '서울내과',
            department: department,
<<<<<<< HEAD
            doctorName: doctor,
=======
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
            purpose: purpose,
          );
          if (!mounted) return;
          Navigator.of(context).pop();
<<<<<<< HEAD
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('예약 요청이 완료되었습니다.')),
          );
=======
          showTopBanner(context, '예약 요청이 완료되었습니다.');
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
<<<<<<< HEAD
      return const Center(child: CircularProgressIndicator());
=======
      return const Center(child: LoadingSpinner());
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('다가오는 예약',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_upcoming.isEmpty)
            const Text('다가오는 예약이 없어', style: TextStyle(color: Colors.grey))
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
            const Text('지난 예약이 없어', style: TextStyle(color: Colors.grey))
          else
            ..._past.map((r) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                        '${r.dateTime.month}.${r.dateTime.day.toString().padLeft(2, '0')} · ${r.hospitalName}'),
                    subtitle: Text(
<<<<<<< HEAD
                        '${r.department} · ${r.purpose} · ${r.doctorName}'),
=======
                        '${r.department}${r.doctorName.isNotEmpty ? ' · ${r.doctorName}' : ''}'),
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
                  ),
                )),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _showNewReservationSheet,
            icon: const Icon(Icons.add),
            label: const Text('새 예약'),
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
    final d = reservation.dateTime;
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdayLabels[d.weekday - 1];
    return Card(
      color: Colors.blue.shade50,
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
<<<<<<< HEAD
                '${reservation.hospitalName} · ${reservation.department} · ${reservation.purpose} · ${reservation.doctorName}'),
=======
              '${reservation.hospitalName} · ${reservation.department} · ${reservation.doctorName}',
              style: const TextStyle(color: Colors.grey),
            ),
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
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

enum _VisitPurposeCategory { consult, document }

class _NewReservationSheet extends StatefulWidget {
  final ReservationService reservationService;
  final VisitService visitService;
  final Future<void> Function(
<<<<<<< HEAD
          DateTime dateTime, String department, String doctor, String purpose)
      onSubmit;
=======
      DateTime dateTime, String department, String purpose) onSubmit;
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

  const _NewReservationSheet({
    required this.reservationService,
    required this.visitService,
    required this.onSubmit,
  });

  @override
  State<_NewReservationSheet> createState() => _NewReservationSheetState();
}

class _NewReservationSheetState extends State<_NewReservationSheet> {
  String? _department;
<<<<<<< HEAD
  String? _doctor;
=======
  List<Department> _departments = [];
  bool _loadingDepartments = true;

>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  _VisitPurposeCategory _category = _VisitPurposeCategory.consult;

  VisitType? _visitType;
  final _symptomController = TextEditingController();
  Visit? _lastVisit;
  bool _loadingLastVisit = false;

  String? _documentType;

  DateTime? _dateTime;
  bool _isSubmitting = false;

<<<<<<< HEAD
  bool get _canSubmit {
    if (_department == null || _doctor == null || _dateTime == null)
      return false;
=======
  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    final list = await widget.reservationService.fetchDepartments();
    if (!mounted) return;
    setState(() {
      _departments = list;
      _loadingDepartments = false;
    });
  }

  bool get _canSubmit {
    if (_department == null || _dateTime == null) return false;
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
    if (_category == _VisitPurposeCategory.consult) {
      return _visitType != null && _symptomController.text.trim().isNotEmpty;
    }
    return _documentType != null;
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;
    setState(() => _dateTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  // 재진 + 진료과가 정해지면 그 과의 최근 방문 기록을 불러와서 보여준다.
  Future<void> _loadLastVisitIfNeeded() async {
    if (_category != _VisitPurposeCategory.consult ||
        _visitType != VisitType.follow) {
      setState(() => _lastVisit = null);
      return;
    }
    setState(() => _loadingLastVisit = true);
    final visit =
        await widget.visitService.fetchLatestVisit(department: _department);
    if (!mounted) return;
    setState(() {
      _lastVisit = visit;
      _loadingLastVisit = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final purpose = _category == _VisitPurposeCategory.consult
        ? '진료 · ${_visitType!.label} · ${_symptomController.text.trim()}'
        : '서류 발급 · $_documentType';

<<<<<<< HEAD
    // 실제 저장/팝업 닫기/스낵바는 부모(ReservationScreen)의 onSubmit이 다 처리한다 —
    // 여기서는 값만 넘겨준다.
    await widget.onSubmit(_dateTime!, _department!, _doctor!, purpose);
=======
    await widget.onSubmit(_dateTime!, _department!, purpose);
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

    if (!mounted) return;
    setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final departments = ReservationService.departments;
    final doctors = ReservationService.doctors;
=======
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
    final documentTypes = ReservationService.documentTypes;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('새 예약',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
<<<<<<< HEAD
            DropdownButtonFormField<String>(
              value: _department,
              decoration: const InputDecoration(
                  labelText: '진료과', border: OutlineInputBorder()),
              items: departments
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) {
                setState(() => _department = v);
                _loadLastVisitIfNeeded();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _doctor,
              decoration: const InputDecoration(
                  labelText: '의사', border: OutlineInputBorder()),
              items: doctors
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => _doctor = v),
            ),
=======
            _loadingDepartments
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  )
                : DropdownButtonFormField<String>(
                    value: _department,
                    decoration: const InputDecoration(
                        labelText: '진료과', border: OutlineInputBorder()),
                    items: _departments
                        .map((d) => DropdownMenuItem(
                            value: d.name, child: Text(d.name)))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _department = v);
                      _loadLastVisitIfNeeded();
                    },
                  ),
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
            const SizedBox(height: 16),
            const Text('방문 목적', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('진료'),
                  selected: _category == _VisitPurposeCategory.consult,
                  onSelected: (_) =>
                      setState(() => _category = _VisitPurposeCategory.consult),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('서류 발급'),
                  selected: _category == _VisitPurposeCategory.document,
                  onSelected: (_) => setState(
                      () => _category = _VisitPurposeCategory.document),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_category == _VisitPurposeCategory.consult) ...[
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('초진'),
                    selected: _visitType == VisitType.first,
                    onSelected: (_) {
                      setState(() => _visitType = VisitType.first);
                      _loadLastVisitIfNeeded();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('재진'),
                    selected: _visitType == VisitType.follow,
                    onSelected: (_) {
                      setState(() => _visitType = VisitType.follow);
                      _loadLastVisitIfNeeded();
                    },
                  ),
                ],
              ),
              if (_visitType == VisitType.follow) ...[
                const SizedBox(height: 8),
                if (_loadingLastVisit)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (_lastVisit != null)
                  Card(
                    color: AppColors.surfaceMuted,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('저번 방문 기록',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                              '${_lastVisit!.date.year}.${_lastVisit!.date.month}.${_lastVisit!.date.day} · ${_lastVisit!.department}'),
                          Text(_lastVisit!.memo,
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  const Text('이 진료과의 이전 방문 기록이 없어요',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _symptomController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '증상',
                  hintText: '어디가 아프신가요?',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                value: _documentType,
                decoration: const InputDecoration(
                    labelText: '서류 종류', border: OutlineInputBorder()),
                items: documentTypes
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => _documentType = v),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _dateTime == null
                    ? '날짜·시간 선택'
                    : '${_dateTime!.month}.${_dateTime!.day} ${_dateTime!.hour.toString().padLeft(2, '0')}:${_dateTime!.minute.toString().padLeft(2, '0')}',
              ),
              onPressed: _pickDateTime,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_canSubmit && !_isSubmitting) ? _submit : null,
                child: _isSubmitting
<<<<<<< HEAD
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
=======
                    ? const LoadingSpinner(size: 20)
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
                    : const Text('예약하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
