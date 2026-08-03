import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/routes.dart';


class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('로그인'),
            const SizedBox(height: 16),
            FilledButton(
              // 3단계까지는 임시. 4단계에서 authProvider로 대체된다
              onPressed: () => context.go(Routes.dashboard),
              child: const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}