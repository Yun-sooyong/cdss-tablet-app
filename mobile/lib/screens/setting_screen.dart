import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/medication_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import '../widgets/loading_spinner.dart';

class SettingsScreen extends StatefulWidget {
  final AuthService authService;
  final NotificationService notificationService;
  final MedicationService medicationService;

  const SettingsScreen({
    super.key,
    required this.authService,
    required this.notificationService,
    required this.medicationService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await widget.notificationService.isEnabled();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await widget.notificationService.setEnabled(value);
    if (value) {
      final doses = await widget.medicationService.fetchTodayDoses();
      await widget.notificationService.scheduleDailyDoseReminders(doses);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('로그아웃')),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(authService: widget.authService)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: _isLoading
          ? const Center(child: LoadingSpinner())
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('개인정보 수정'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EditProfileScreen(authService: widget.authService)),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('비밀번호 변경'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ChangePasswordScreen(authService: widget.authService)),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('복약 알림'),
                  subtitle: const Text('전체 복약 알림을 켜거나 꺼요'),
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
                  onTap: _confirmLogout,
                ),
              ],
            ),
    );
  }
}