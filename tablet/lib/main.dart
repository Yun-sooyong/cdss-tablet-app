import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/screens/dashboard.dart';
import 'package:tablet/screens/login_screen.dart';

void main(List<String> args) {
  runApp(const ProviderScope(child: Myapp()));
}

class Myapp extends HookConsumerWidget {
  const Myapp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLogin = useState(true);
    return MaterialApp(
      title: 'VitaTree',
      theme: VitaTreeTheme.light,
      home: isLogin.value ? DashboardScreen() : LoginScreen(),
    );
  }
}
