import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/medication_service.dart';
import '../services/reservation_service.dart';
import '../theme/app_colors.dart';
import 'settings_screen.dart';
import 'prescription_info_screen.dart';
import '../services/notification_service.dart';

class MyPageScreen extends StatefulWidget {
  final AuthService authService;
  final MedicationService medicationService;
  final ReservationService reservationService;
  final NotificationService notificationService;

  const MyPageScreen({
    super.key,
    required this.authService,
    required this.medicationService,
    required this.reservationService,
    required this.notificationService,
  });

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  double? _adherenceRate;
  DateTime? _nextReservationDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final adherenceFuture = widget.medicationService.fetchWeeklyAdherence();
    final reservationsFuture = widget.reservationService.fetchUpcoming();

    final adherence = await adherenceFuture;
    final reservations = await reservationsFuture;
    if (!mounted) return;
    setState(() {
      _adherenceRate = adherence.rate;
      _nextReservationDate =
          reservations.isNotEmpty ? reservations.first.dateTime : null;
      _isLoading = false;
    });
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '없음';
    return '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.authService.currentPatient;
    final name = patient?.name ?? '환자';
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';

    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('설정'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              authService: widget.authService,
                              notificationService: widget.notificationService,
                              medicationService: widget.medicationService,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primary,
                            child: Text(initial,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 20)),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$name 님',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text('환자',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryLinkCard(
                    leadingIcon: Icons.pie_chart_outline,
                    leadingLabel: '복약률',
                    leadingValue: '${((_adherenceRate ?? 0) * 100).round()}%',
                    leadingPercent: _adherenceRate,
                    trailingIcon: Icons.description_outlined,
                    trailingLine1: '처방 내역',
                    onTapTrailing: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PrescriptionInfoScreen(
                            medicationService: widget.medicationService),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Icon(Icons.event_note_outlined,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('다음 예약',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                              Text(_fmtDate(_nextReservationDate),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// 왼쪽엔 통계, 오른쪽엔 탭 가능한 이동 링크가 나란히 있는 카드.
// 지금은 "복약률 → 처방내역" 한 곳에서만 쓰여.
class _SummaryLinkCard extends StatelessWidget {
  final IconData leadingIcon;
  final String leadingLabel;
  final String leadingValue;
  final IconData trailingIcon;
  final double? leadingPercent;
  final String trailingLine1;
  final VoidCallback onTapTrailing;

  const _SummaryLinkCard({
    required this.leadingIcon,
    required this.leadingLabel,
    required this.leadingValue,
    required this.trailingIcon,
    this.leadingPercent,
    required this.trailingLine1,
    required this.onTapTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  leadingPercent != null
                      ? SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            value: leadingPercent!.clamp(0.0, 1.0),
                            strokeWidth: 4,
                            backgroundColor: AppColors.surfaceMuted,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                          ),
                        )
                      : Icon(leadingIcon, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(leadingLabel,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      Text(leadingValue,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 36, color: AppColors.surfaceMuted),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: onTapTrailing,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Icon(trailingIcon, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trailingLine1,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
