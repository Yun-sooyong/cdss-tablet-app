import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/medication_service.dart';
import '../services/visit_service.dart';
import '../services/reservation_service.dart';
import '../models/dose.dart';
import '../theme/app_colors.dart';
<<<<<<< HEAD
=======
import 'dart:math';
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

class DashboardScreen extends StatefulWidget {
  final AuthService authService;
  final MedicationService medicationService;
  final VisitService visitService;
  final ReservationService reservationService;
  final void Function(int tabIndex) onNavigate;
  final VoidCallback onOpenQr;

  const DashboardScreen({
    super.key,
    required this.authService,
    required this.medicationService,
    required this.visitService,
    required this.reservationService,
    required this.onNavigate,
    required this.onOpenQr,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// MainShell 탭 순서(약관리=1, 진료내역=2, QR=3, 예약=4, 마이페이지=5)와 반드시 맞춰야 함.
class _TabIndex {
  static const medication = 1;
  static const visit = 3;
  static const reservation = 4;
}

class _DashboardScreenState extends State<DashboardScreen> {
  double? _adherenceRate;
  List<DoseItem> _todayDoses = [];
  String? _latestVisitSummary;
  String? _nextReservationSummary;
  bool _isLoading = true;
<<<<<<< HEAD
=======
  static const List<String> _greetingMessages = [
    '오늘도 건강 관리 잊지 마세요',
    '꾸준함이 제일 중요해요, 오늘도 화이팅!',
    '물 한 잔 마시고 시작해볼까요?',
    '약 챙기는 것도 건강 관리의 시작이에요',
    '오늘 컨디션은 어떠세요?',
    '작은 습관이 큰 변화를 만들어요',
    ];

    String _greetingMessage = '오늘도 건강 관리 잊지 마세요';
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
=======
    _greetingMessage = _greetingMessages[Random().nextInt(_greetingMessages.length)];
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final adherenceFuture = widget.medicationService.fetchWeeklyAdherence();
    final dosesFuture = widget.medicationService.fetchTodayDoses();
    final visitsFuture = widget.visitService.fetchVisits();
    final reservationsFuture = widget.reservationService.fetchUpcoming();

    final adherence = await adherenceFuture;
    final doses = await dosesFuture;
    final visits = await visitsFuture;
    final reservations = await reservationsFuture;
    if (!mounted) return;
    setState(() {
      _adherenceRate = adherence.rate;
      _todayDoses = doses;
<<<<<<< HEAD
      _latestVisitSummary = visits.isNotEmpty
          ? '${_fmtDate(visits.first.date)} · ${visits.first.department}'
          : '기록 없음';
      _nextReservationSummary = reservations.isNotEmpty
          ? '${_fmtDate(reservations.first.dateTime)} · ${reservations.first.hospitalName}'
          : '예약 없음';
=======
      _latestVisitSummary = visits.isNotEmpty ? '${_fmtDate(visits.first.date)} · ${visits.first.department}' : '기록 없음';
      _nextReservationSummary = reservations.isNotEmpty ? '${_fmtDate(reservations.first.dateTime)} · ${reservations.first.hospitalName}' : '예약 없음';
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
      _isLoading = false;
    });
  }

<<<<<<< HEAD
  String _fmtDate(DateTime d) =>
      '${d.month}.${d.day.toString().padLeft(2, '0')}';
=======
  String _fmtDate(DateTime d) => '${d.month}.${d.day.toString().padLeft(2, '0')}';
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

  @override
  Widget build(BuildContext context) {
    final patient = widget.authService.currentPatient;
    return SafeArea(
<<<<<<< HEAD
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        child: Icon(Icons.person),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${patient?.name ?? '환자'}님, 안녕하세요',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            '오늘도 건강 관리 잊지 마세요',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _DashboardCard(
                        icon: Icons.medication_outlined,
                        label: '약 관리',
                        value: '복약률 ${((_adherenceRate ?? 0) * 100).round()}%',
                        onTap: () => widget.onNavigate(_TabIndex.medication),
                      ),
                      _DashboardCard(
                        icon: Icons.history_outlined,
                        label: '진료내역',
                        value: _latestVisitSummary ?? '-',
                        onTap: () => widget.onNavigate(_TabIndex.visit),
                      ),
                      _DashboardCard(
                        icon: Icons.event_outlined,
                        label: '예약 관리',
                        value: _nextReservationSummary ?? '-',
                        onTap: () => widget.onNavigate(_TabIndex.reservation),
                      ),
                      _DashboardCard(
                        icon: Icons.qr_code_outlined,
                        label: 'QR 발급',
                        value: '환자 확인용',
                        onTap: widget.onOpenQr,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '오늘 복용',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._todayDoses.take(2).map(
                        (dose) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              dose.taken
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color:
                                  dose.taken ? AppColors.primary : Colors.grey,
                            ),
                            title: Text(
                              '${dose.time.label} · ${dose.medicationName}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                widget.onNavigate(_TabIndex.medication),
                          ),
                        ),
                      ),
                ],
              ),
            ),
=======
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(radius: 24, child: Icon(Icons.person)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${patient?.name ?? '환자'}님, 안녕하세요', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(_greetingMessage, style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _DashboardCard(
                          icon: Icons.medication_outlined,
                          label: '약 관리',
                          value: '복약률 ${((_adherenceRate ?? 0) * 100).round()}%',
                          onTap: () => widget.onNavigate(_TabIndex.medication),
                        ),
                        _DashboardCard(
                          icon: Icons.history_outlined,
                          label: '진료내역',
                          value: _latestVisitSummary ?? '-',
                          onTap: () => widget.onNavigate(_TabIndex.visit),
                        ),
                        _DashboardCard(
                          icon: Icons.event_outlined,
                          label: '예약 관리',
                          value: _nextReservationSummary ?? '-',
                          onTap: () => widget.onNavigate(_TabIndex.reservation),
                        ),
                        _DashboardCard(
                          icon: Icons.qr_code_outlined,
                          label: 'QR 발급',
                          value: '환자 확인용',
                          onTap: widget.onOpenQr, 
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('오늘 복용', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._todayDoses.take(2).map((dose) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              dose.taken ? Icons.check_circle : Icons.circle_outlined,
                              color: dose.taken ? AppColors.primary : Colors.grey,
                            ),
                            title: Text('${dose.time.label} · ${dose.medicationName}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => widget.onNavigate(_TabIndex.medication),
                          ),
                        )),
                  ],
                ),
            ),
      ),
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

<<<<<<< HEAD
  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
=======
  const _DashboardCard({required this.icon, required this.label, required this.value, required this.onTap});
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
<<<<<<< HEAD
              Text(
                value,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
=======
              Text(value, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
            ],
          ),
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
