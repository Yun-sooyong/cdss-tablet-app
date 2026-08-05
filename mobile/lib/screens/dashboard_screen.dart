import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/medication_service.dart';
import '../services/visit_service.dart';
import '../services/reservation_service.dart';
import '../models/dose.dart';
import '../models/reservation.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_spinner.dart';
import 'dart:math';

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
  Reservation? _nextReservation;
  bool _isLoading = true;

  static const List<String> _subtitleMessages = [
    '오늘도 건강한 하루 보내세요.',
    '꾸준함이 제일 중요해요, 오늘도 화이팅!',
    '물 한 잔 마시고 시작해볼까요?',
    '약 챙기는 것도 건강 관리의 시작이에요.',
    '오늘 컨디션은 어떠세요?',
    '작은 습관이 큰 변화를 만들어요.',
  ];
  late final String _subtitleMessage;

  @override
  void initState() {
    super.initState();
    _subtitleMessage =
        _subtitleMessages[Random().nextInt(_subtitleMessages.length)];
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
    await visitsFuture; // 홈 화면엔 더 이상 요약을 안 띄우지만, 다른 탭 캐시 워밍 겸 호출만 유지
    final reservations = await reservationsFuture;
    if (!mounted) return;
    setState(() {
      _adherenceRate = adherence.rate;
      _todayDoses = doses;
      _nextReservation = reservations.isNotEmpty ? reservations.first : null;
      _isLoading = false;
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '좋은 아침입니다';
    if (hour < 18) return '좋은 오후입니다';
    return '좋은 저녁입니다';
  }

  String _fmtReservationDate(DateTime d) {
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdayLabels[d.weekday - 1];
    return '${d.month}월 ${d.day}일 ($weekday) ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final patient = widget.authService.currentPatient;
    final name = patient?.name ?? '환자';
    final initial = name.isNotEmpty ? name.substring(0, 1) : '환';
    final DoseItem? nextDose = _todayDoses.where((d) => !d.taken).isNotEmpty
        ? _todayDoses.firstWhere((d) => !d.taken)
        : (_todayDoses.isNotEmpty ? _todayDoses.first : null);

    return SafeArea(
      child: _isLoading
          ? const Center(child: LoadingSpinner())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.secondary,
                        child: Text(initial,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$name님',
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('${_greeting()} 🌿',
                                style: const TextStyle(fontSize: 13)),
                            Text(_subtitleMessage,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_none),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('알림함은 아직 준비 중이에요.')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Stack(
                        children: [
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Icon(Icons.eco,
                                size: 64,
                                color: AppColors.primary.withOpacity(0.12)),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('오늘 복용',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text(
                                nextDose != null
                                    ? _fmtTime(nextDose.date)
                                    : '복용 일정 없음',
                                style: const TextStyle(
                                    fontSize: 26, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(nextDose?.medicationName ?? '',
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 12),
                              if (nextDose != null)
                                _StatusBadge(taken: nextDose.taken),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_nextReservation != null)
                    InkWell(
                      onTap: () => widget.onNavigate(_TabIndex.reservation),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF3A362E)
                              : const Color(0xFFF3E9DC), // 근사치, 정확한 값 나오면 교체
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('다음 예약',
                                      style: TextStyle(
                                          fontSize: 13, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _fmtReservationDate(
                                        _nextReservation!.dateTime),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                  Text(
                                    '${_nextReservation!.hospitalName} · ${_nextReservation!.department}',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.calendar_today,
                                color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _DashboardCard(
                        icon: Icons.medication_outlined,
                        label: '약 관리',
                        onTap: () => widget.onNavigate(_TabIndex.medication),
                      ),
                      _DashboardCard(
                        icon: Icons.event_outlined,
                        label: '예약 관리',
                        onTap: () => widget.onNavigate(_TabIndex.reservation),
                      ),
                      _DashboardCard(
                        icon: Icons.description_outlined,
                        label: '진료내역',
                        onTap: () => widget.onNavigate(_TabIndex.visit),
                      ),
                      _DashboardCard(
                        icon: Icons.qr_code_outlined,
                        label: 'QR 발급',
                        onTap: widget.onOpenQr,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool taken;
  const _StatusBadge({required this.taken});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: taken
            ? AppColors.primary.withOpacity(0.12)
            : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(taken ? Icons.check_circle : Icons.schedule,
              size: 16, color: taken ? AppColors.primary : Colors.grey),
          const SizedBox(width: 4),
          Text(taken ? '복용 완료' : '복용 예정',
              style: TextStyle(
                  fontSize: 12,
                  color: taken ? AppColors.primary : Colors.grey,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DashboardCard(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 26),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
