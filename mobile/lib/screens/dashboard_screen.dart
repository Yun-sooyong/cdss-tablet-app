import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/medication_service.dart';
import '../services/visit_service.dart';
import '../services/reservation_service.dart';
import '../services/streak_service.dart';
import '../models/dose.dart';
import '../models/reservation.dart';
import '../services/notification_feed_service.dart';
import '../constants/hospital_info.dart';
import '../widgets/loading_spinner.dart';
import 'notifications_screen.dart';
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
  // late final 대신 필드 초기화 시점에 바로 값을 넣는다 — late 필드는 핫 리로드로 새
  // 필드가 추가된 기존 화면 인스턴스에서 initState()가 다시 안 불려서
  // LateInitializationError가 나는 경우가 있음(핫 리스타트 전까지).
  static const List<String> _healthTips = [
    '하루 물 8잔, 신진대사와 컨디션 관리에 도움이 돼요.',
    '식후 30분 가벼운 산책은 소화와 혈당 조절에 좋아요.',
    '창문을 열고 5분만 환기해도 실내 공기가 훨씬 맑아져요.',
    '잠들기 1시간 전 화면을 멀리하면 수면의 질이 좋아져요.',
    '하루 10분 스트레칭은 근육 긴장을 풀어주고 순환을 도와요.',
    '카페인은 오후 3시 이후엔 되도록 줄이는 게 숙면에 좋아요.',
    '앉아 있는 시간이 길다면 1시간마다 잠깐씩 일어나 움직여보세요.',
    '깊게 숨을 들이쉬는 것만으로도 스트레스 완화에 도움이 돼요.',
  ];

  final String _subtitleMessage =
      _subtitleMessages[Random().nextInt(_subtitleMessages.length)];
  final String _healthTip = _healthTips[Random().nextInt(_healthTips.length)];

  int? _streak;

  @override
  void initState() {
    super.initState();
    StreakService.instance.recordVisitAndGetStreak().then((streak) {
      if (!mounted) return;
      setState(() => _streak = streak);
    });
    _load();
  }

  Future<void> _callHospital(BuildContext context) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: kHospitalPhone));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결할 수 있는 앱을 찾지 못했어요.')),
      );
    }
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
    final colorScheme = Theme.of(context).colorScheme;
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
                        backgroundColor: colorScheme.secondary,
                        child: Text(initial,
                            style: TextStyle(
                                color: colorScheme.primary,
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
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      if (_streak != null && _streak! > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🌱', style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                              Text('$_streak일째',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary)),
                            ],
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.notifications_none),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => NotificationsScreen(
                                  service: NotificationFeedService())),
                        ),
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
                                color: colorScheme.primary.withOpacity(0.12)),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('오늘 복용',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant)),
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
                                  Text('다음 예약',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.onSurfaceVariant)),
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
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.calendar_today,
                                color: colorScheme.primary),
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
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: colorScheme.primary.withOpacity(0.15),
                            child: Icon(Icons.eco_outlined,
                                color: colorScheme.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('오늘의 건강 팁',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(_healthTip,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurfaceVariant,
                                        height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _callHospital(context),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              child: Icon(Icons.local_hospital_outlined,
                                  color: colorScheme.primary, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(kHospitalName,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(kHospitalHours,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Icon(Icons.call_outlined,
                                color: colorScheme.primary, size: 20),
                          ],
                        ),
                      ),
                    ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: taken
            ? colorScheme.primary.withOpacity(0.12)
            : colorScheme.onSurfaceVariant.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(taken ? Icons.check_circle : Icons.schedule,
              size: 16,
              color: taken ? colorScheme.primary : colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(taken ? '복용 완료' : '복용 예정',
              style: TextStyle(
                  fontSize: 12,
                  color:
                      taken ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colorScheme.primary, size: 26),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
