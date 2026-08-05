import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/medication_service.dart';
import '../services/visit_service.dart';
import '../services/reservation_service.dart';
import '../services/qr_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'medication_screen.dart';
import 'visit_history_screen.dart';
import 'qr_screen.dart';
import 'reservation_screen.dart';
import 'mypage_screen.dart';

// 탭 인덱스: 0=홈, 1=약관리, 2=마이페이지(가운데, 강조), 3=진료내역, 4=예약관리.
class MainShell extends StatefulWidget {
  final AuthService authService;

  const MainShell({super.key, required this.authService});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _medicationService = MedicationService();
  final _visitService = VisitService();
  final _reservationService = ReservationService();
  final _qrService = QrService();
  final _notificationService = NotificationService();

  void _goToTab(int index) => setState(() => _index = index);

  void _openQr() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => QrScreen(qrService: _qrService)),
    );
  }

  @override
  void initState() {
    super.initState();
    _notificationService.init();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        authService: widget.authService,
        medicationService: _medicationService,
        visitService: _visitService,
        reservationService: _reservationService,
        onNavigate: _goToTab,
        onOpenQr: _openQr,
      ),
      MedicationScreen(
        medicationService: _medicationService,
        notificationService: _notificationService,
      ),
      MyPageScreen(
        authService: widget.authService,
        medicationService: _medicationService,
        reservationService: _reservationService,
        notificationService: _notificationService,
        onNavigate: (i) => setState(() => _index = i),
      ),
      VisitHistoryScreen(visitService: _visitService),
      ReservationScreen(
        reservationService: _reservationService,
        visitService: _visitService,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('V-Tree'),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code), onPressed: _openQr),
        ],
      ),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: SizedBox(
        height: 70,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Row(
              children: [
                Expanded(
                    child: _NavItem(
                        icon: Icons.home,
                        label: '홈',
                        selected: _index == 0,
                        onTap: () => _goToTab(0))),
                Expanded(
                    child: _NavItem(
                        icon: Icons.medication,
                        label: '약',
                        selected: _index == 1,
                        onTap: () => _goToTab(1))),
                const Expanded(
                    child: SizedBox()), // 가운데는 비워둠 — 마이페이지 원형 버튼이 그 위에 떠 있음
                Expanded(
                    child: _NavItem(
                        icon: Icons.history,
                        label: '진료',
                        selected: _index == 3,
                        onTap: () => _goToTab(3))),
                Expanded(
                    child: _NavItem(
                        icon: Icons.event,
                        label: '예약',
                        selected: _index == 4,
                        onTap: () => _goToTab(4))),
              ],
            ),
            Positioned(
              top: -20,
              child: GestureDetector(
                onTap: () => _goToTab(2),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _index == 2 ? AppColors.primary : AppColors.secondary,
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2))
                    ],
                  ),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : Colors.grey;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
