import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/medication_service.dart';
import '../services/theme_controller.dart';
import '../widgets/loading_spinner.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'policy_screen.dart';
import '../constants/policy_content.dart';

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
    widget.authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => LoginScreen(authService: widget.authService)),
      (route) => false,
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('탈퇴하면 계정 정보와 이용 기록이 모두 삭제되고 복구할 수 없어요.\n정말 탈퇴할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('탈퇴',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (firstConfirm != true) return;
    if (!mounted) return;

    final controller = TextEditingController();
    final typed = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('탈퇴 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('진짜 탈퇴하려면 아래에 "탈퇴"라고 입력해줘.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (typed != '탈퇴') {
      if (typed != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('"탈퇴"라고 정확히 입력해야 진행돼.')),
        );
      }
      return;
    }

    try {
      await widget.authService.deleteAccount();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('탈퇴에 실패했어요: $e')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => LoginScreen(authService: widget.authService)),
      (route) => false,
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '시스템 설정 따라가기';
      case ThemeMode.light:
        return '라이트 모드';
      case ThemeMode.dark:
        return '다크 모드';
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
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
                    MaterialPageRoute(
                        builder: (_) =>
                            EditProfileScreen(authService: widget.authService)),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('비밀번호 변경'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => ChangePasswordScreen(
                            authService: widget.authService)),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('복약 알림'),
                  subtitle: const Text('전체 복약 알림을 켜거나 꺼요'),
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.instance.mode,
                  builder: (context, mode, _) => ListTile(
                    leading: const Icon(Icons.brightness_6_outlined),
                    title: const Text('화면 테마'),
                    subtitle: Text(_themeModeLabel(mode)),
                    trailing: PopupMenuButton<ThemeMode>(
                      icon: const Icon(Icons.chevron_right),
                      onSelected: (m) => ThemeController.instance.setMode(m),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                            value: ThemeMode.system,
                            child: Text('시스템 설정 따라가기')),
                        PopupMenuItem(
                            value: ThemeMode.light, child: Text('라이트 모드')),
                        PopupMenuItem(
                            value: ThemeMode.dark, child: Text('다크 모드')),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('이용약관'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PolicyScreen(
                        title: '이용약관',
                        version: kTermsVersion,
                        revisedDate: kTermsRevisedDate,
                        intro: kTermsIntro,
                        sections: kTermsSections,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('개인정보처리방침'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PolicyScreen(
                        title: '개인정보처리방침',
                        version: kPrivacyVersion,
                        revisedDate: kPrivacyRevisedDate,
                        intro: kPrivacyIntro,
                        sections: kPrivacySections,
                      ),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.logout, color: error),
                  title: Text('로그아웃', style: TextStyle(color: error)),
                  onTap: _confirmLogout,
                ),
                ListTile(
                  leading: Icon(Icons.person_remove_outlined, color: error),
                  title: Text('회원 탈퇴', style: TextStyle(color: error)),
                  onTap: _confirmDeleteAccount,
                ),
              ],
            ),
    );
  }
}
