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

  void _goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        authService: widget.authService,
        medicationService: _medicationService,
        visitService: _visitService,
        reservationService: _reservationService,
        onNavigate: _goToTab,
      ),
      MedicationScreen(medicationService: _medicationService),
      VisitHistoryScreen(visitService: _visitService),
      QrScreen(qrService: _qrService),
      ReservationScreen(reservationService: _reservationService),
      MyPageScreen(authService: widget.authService),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: '약관리',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '진료내역',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_outlined),
            selectedIcon: Icon(Icons.qr_code),
            label: 'QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: '예약',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '마이페이지',
          ),
        ],
      ),
    );
  }
}
