import 'package:flutter/material.dart';
import '../models/department.dart';
import '../models/reservation.dart';
import '../models/visit.dart';
import '../services/reservation_service.dart';
import '../services/visit_service.dart';
import '../widgets/loading_spinner.dart';

enum _VisitPurposeCategory { consult, document }

class NewReservationScreen extends StatefulWidget {
  final ReservationService reservationService;
  final VisitService visitService;

  const NewReservationScreen({
    super.key,
    required this.reservationService,
    required this.visitService,
  });

  @override
  State<NewReservationScreen> createState() => _NewReservationScreenState();
}

class _NewReservationScreenState extends State<NewReservationScreen> {
  int _step = 0; // 0:날짜 1:시간 2:정보입력 3:확인

  List<Department> _departments = [];
  bool _loadingDepartments = true;
  Department? _selectedDepartment;

  DateTime _selectedDate = DateTime.now();
  List<TimeSlot> _slots = [];
  bool _loadingSlots = false;
  TimeSlot? _selectedTime;

  _VisitPurposeCategory _category = _VisitPurposeCategory.consult;
  VisitType? _visitType;
  final _symptomController = TextEditingController();
  Visit? _lastVisit;
  bool _loadingLastVisit = false;
  ReservationDocumentType? _documentType;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    final list = await widget.reservationService.fetchDepartments();
    if (!mounted) return;
    setState(() {
      _departments = list;
      _selectedDepartment = list.isNotEmpty ? list.first : null;
      _loadingDepartments = false;
    });
  }

  Future<void> _pickDepartment() async {
    final picked = await showModalBottomSheet<Department>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: _departments
              .map((d) => ListTile(
                    title: Text(d.name),
                    trailing: d.code == _selectedDepartment?.code
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(d),
                  ))
              .toList(),
        ),
      ),
    );
    if (picked != null) {
      setState(() => _selectedDepartment = picked);
      _loadLastVisitIfNeeded();
    }
  }

  Future<void> _loadSlots() async {
    if (_selectedDepartment == null) return;
    setState(() => _loadingSlots = true);
    final slots = await widget.reservationService
        .fetchAvailableSlots(_selectedDepartment!.code, _selectedDate);
    if (!mounted) return;
    setState(() {
      _slots = slots;
      _selectedTime = null;
      _loadingSlots = false;
    });
  }

  Future<void> _loadLastVisitIfNeeded() async {
    if (_category != _VisitPurposeCategory.consult ||
        _visitType != VisitType.follow) {
      setState(() => _lastVisit = null);
      return;
    }
    setState(() => _loadingLastVisit = true);
    final visit = await widget.visitService
        .fetchLatestVisit(department: _selectedDepartment?.name);
    if (!mounted) return;
    setState(() {
      _lastVisit = visit;
      _loadingLastVisit = false;
    });
  }

  bool get _canSubmitInfo {
    if (_category == _VisitPurposeCategory.consult) {
      return _visitType != null && _symptomController.text.trim().isNotEmpty;
    }
    return _documentType != null;
  }

  // 확인 단계에 보여주기만 하는 요약 텍스트 — 서버로는 reason/documentType이 따로 감.
  String get _purposeText => _category == _VisitPurposeCategory.consult
      ? '진료 · ${_visitType!.label} · ${_symptomController.text.trim()}'
      : '서류 발급 · ${_documentType!.label}';

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final dateTime = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _selectedTime!.hour, _selectedTime!.minute);
    try {
      await widget.reservationService.requestNew(
        dateTime: dateTime,
        hospitalName: '서울내과',
        department: _selectedDepartment!.name,
        reason: _category == _VisitPurposeCategory.consult
            ? '${_visitType!.label} · ${_symptomController.text.trim()}'
            : '',
        documentType: _category == _VisitPurposeCategory.document
            ? _documentType!
            : ReservationDocumentType.none,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('예약 신청에 실패했어요: $e')));
    }
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step -= 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('예약하기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _StepIndicator(currentStep: _step),
            ),
            const Divider(height: 1),
            Expanded(child: _buildStepBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return _buildDateStep();
      case 1:
        return _buildTimeStep();
      case 2:
        return _buildInfoStep();
      default:
        return _buildConfirmStep();
    }
  }

  Widget _buildDateStep() {
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SelectedChipRow(
          icon: Icons.calendar_today_outlined,
          label: '진료 과목',
          value: _loadingDepartments
              ? '불러오는 중...'
              : (_selectedDepartment?.name ?? '선택 필요'),
          onChange: _loadingDepartments ? null : _pickDepartment,
        ),
        const SizedBox(height: 20),
        const Text('날짜를 선택해주세요',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        CalendarDatePicker(
          initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
          firstDate: today,
          lastDate: DateTime(today.year + 1, today.month, today.day),
          onDateChanged: (d) => setState(() => _selectedDate = d),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _selectedDepartment == null
                ? null
                : () async {
                    await _loadSlots();
                    if (!mounted) return;
                    setState(() => _step = 1);
                  },
            child: const Text('다음'),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeStep() {
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdayLabels[_selectedDate.weekday - 1];
    final morning = _slots.where((s) => s.hour < 12).toList();
    final afternoon = _slots.where((s) => s.hour >= 12).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SelectedChipRow(
          icon: Icons.calendar_today_outlined,
          label: '선택한 날짜',
          value:
              '${_selectedDate.year}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.day.toString().padLeft(2, '0')} ($weekday)',
          onChange: () => setState(() => _step = 0),
        ),
        const SizedBox(height: 20),
        const Text('시간을 선택해주세요',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('모든 시간은 30분 단위로 예약됩니다.',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        if (_loadingSlots)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: LoadingSpinner()),
          )
        else if (_slots.isEmpty)
          Text('이 진료과는 예약 가능한 시간이 없어요',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
        else ...[
          const Text('오전', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _timeGrid(morning),
          const SizedBox(height: 16),
          const Text('오후', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _timeGrid(afternoon),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed:
                _selectedTime == null ? null : () => setState(() => _step = 2),
            child: const Text('다음'),
          ),
        ),
      ],
    );
  }

  Widget _timeGrid(List<TimeSlot> slots) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: slots.map((slot) {
        final selected = _selectedTime?.time == slot.time;
        final colorScheme = Theme.of(context).colorScheme;
        if (!slot.available) {
          return OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              side: BorderSide(color: colorScheme.outline),
            ),
            child: Text(
              slot.time,
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough),
            ),
          );
        }
        final primary = colorScheme.primary;
        return OutlinedButton(
          onPressed: () => setState(() => _selectedTime = slot),
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? primary : null,
            side: BorderSide(color: selected ? primary : colorScheme.outline),
          ),
          child: Text(slot.time,
              style: TextStyle(color: selected ? Colors.white : null)),
        );
      }).toList(),
    );
  }

  Widget _buildInfoStep() {
    final documentTypes = ReservationService.documentTypes;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
              onSelected: (_) =>
                  setState(() => _category = _VisitPurposeCategory.document),
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                ),
              )
            else
              Text('이 진료과의 이전 방문 기록이 없어요',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12)),
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
          DropdownButtonFormField<ReservationDocumentType>(
            value: _documentType,
            decoration: const InputDecoration(
                labelText: '서류 종류', border: OutlineInputBorder()),
            items: documentTypes
                .map((d) => DropdownMenuItem(value: d, child: Text(d.label)))
                .toList(),
            onChanged: (v) => setState(() => _documentType = v),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _canSubmitInfo ? () => setState(() => _step = 3) : null,
            child: const Text('다음'),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdayLabels[_selectedDate.weekday - 1];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('예약 내용을 확인해주세요',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _confirmRow('진료과', _selectedDepartment?.name ?? ''),
                const Divider(),
                _confirmRow('날짜',
                    '${_selectedDate.year}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.day.toString().padLeft(2, '0')} ($weekday)'),
                const Divider(),
                _confirmRow('시간', _selectedTime?.time ?? ''),
                const Divider(),
                _confirmRow('방문 목적', _purposeText),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const LoadingSpinner(size: 20)
                : const Text('예약 신청하기'),
          ),
        ),
      ],
    );
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: 72,
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class _SelectedChipRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onChange;

  const _SelectedChipRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurfaceVariant)),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (onChange != null)
            OutlinedButton(onPressed: onChange, child: const Text('변경')),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  static const _labels = ['날짜 선택', '시간 선택', '정보 입력', '확인'];

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    return Row(
      children: List.generate(_labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final leftStep = i ~/ 2;
          final done = leftStep < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 18),
              color: done ? primary : colorScheme.outline,
            ),
          );
        }
        final step = i ~/ 2;
        final isActiveOrDone = step <= currentStep;
        return Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isActiveOrDone ? primary : colorScheme.outline,
              child: Text('${step + 1}',
                  style: TextStyle(
                      color: isActiveOrDone
                          ? Colors.white
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
            const SizedBox(height: 4),
            Text(_labels[step],
                style: TextStyle(
                    fontSize: 11,
                    color: step == currentStep
                        ? primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: step == currentStep
                        ? FontWeight.bold
                        : FontWeight.normal)),
          ],
        );
      }),
    );
  }
}
