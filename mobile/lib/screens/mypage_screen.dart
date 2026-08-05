import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/medication_service.dart';
import '../services/reservation_service.dart';
import '../theme/app_colors.dart';
import 'settings_screen.dart';
import 'prescription_info_screen.dart';
import 'document_box_screen.dart';
import 'my_info_screen.dart';
import 'login_screen.dart';
import '../services/notification_service.dart';
import '../widgets/loading_spinner.dart';
import 'report_screen.dart';
import 'customer_service_screen.dart';

class MyPageScreen extends StatefulWidget {
  final AuthService authService;
  final MedicationService medicationService;
  final ReservationService reservationService;
  final NotificationService notificationService;
  final void Function(int tabIndex) onNavigate;

  const MyPageScreen({
    super.key,
    required this.authService,
    required this.medicationService,
    required this.reservationService,
    required this.notificationService,
    required this.onNavigate,
  });

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _TabIndex {
  static const medication = 1;
  static const visit = 3;
  static const reservation = 4;
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

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠어요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('로그아웃')),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => LoginScreen(authService: widget.authService)),
      (route) => false,
    );
  }

  void _notReadyYet(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name 화면은 다음 단계에서 만들 거야.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.authService.currentPatient;
    final name = patient?.name ?? '환자';
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';
    return SafeArea(
      child: _isLoading
          ? const Center(child: LoadingSpinner())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    const Text('마이페이지',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          authService: widget.authService,
                          notificationService: widget.notificationService,
                          medicationService: widget.medicationService,
                        ),
                      )),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            CircleAvatar(
                                radius: 28,
                                backgroundColor: AppColors.primary,
                                child: Text(initial,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 20))),
                            const SizedBox(width: 16),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$name 님',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('건강한 하루 보내세요',
                                      style: TextStyle(color: Colors.grey)),
                                ]),
                          ]))),
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
                                medicationService: widget.medicationService))),
                  ),
                  const SizedBox(height: 12),
                  _SummaryLinkCard(
                    leadingIcon: Icons.event_note_outlined,
                    leadingLabel: '다음 예약',
                    leadingValue: _fmtDate(_nextReservationDate),
                    trailingIcon: Icons.folder_special_outlined,
                    trailingLine1: '진단서·처방전',
                    onTapTrailing: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => DocumentBoxScreen(
                                reservationService:
                                    widget.reservationService))),
                  ),
                  const SizedBox(height: 20),
                  Card(
                      child: Column(children: [
                    _MenuTile(
                        icon: Icons.person_outline,
                        label: '내 정보',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => MyInfoScreen(
                                    authService: widget.authService)))),
                    const Divider(height: 1),
                    _MenuTile(
                        icon: Icons.medication_outlined,
                        label: '복약 관리',
                        onTap: () => widget.onNavigate(_TabIndex.medication)),
                    const Divider(height: 1),
                    _MenuTile(
                        icon: Icons.event_outlined,
                        label: '예약 관리',
                        onTap: () => widget.onNavigate(_TabIndex.reservation)),
                    const Divider(height: 1),
                    _MenuTile(
                        icon: Icons.history_outlined,
                        label: '진료 내역',
                        onTap: () => widget.onNavigate(_TabIndex.visit)),
                    const Divider(height: 1),
                    _MenuTile(
                        icon: Icons.insert_chart_outlined,
                        label: '리포트',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ReportScreen(
                                    medicationService:
                                        widget.medicationService)))),
                    const Divider(height: 1),
                    _MenuTile(
                        icon: Icons.support_agent_outlined,
                        label: '고객센터',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const CustomerServiceScreen()))),
                    const Divider(height: 1),
                    _MenuTile(
                        icon: Icons.logout,
                        label: '로그아웃',
                        iconColor: Colors.red,
                        labelColor: Colors.red,
                        onTap: _confirmLogout),
                  ])),
                ],
              ),
            ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  const _MenuTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.iconColor,
      this.labelColor});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.primary),
      title: Text(label, style: TextStyle(color: labelColor)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

// _SummaryLinkCard는 원래 니 파일 그대로 있던 거니까 지우지 말고 그 아래에 붙여놔.

// 왼쪽엔 통계(복약률/다음예약), 오른쪽엔 탭 가능한 이동 링크가 나란히 있는 카드. (기존 코드 그대로, 안 바뀜)
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
                            backgroundColor: Theme.of(context).dividerColor,
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
            Container(
                width: 1, height: 36, color: Theme.of(context).dividerColor),
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
