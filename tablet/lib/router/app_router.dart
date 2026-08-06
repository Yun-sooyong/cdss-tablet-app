import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:tablet/router/routes.dart';
import 'package:tablet/screens/dashboard_screen.dart';
import 'package:tablet/screens/login_screen.dart';
import 'package:tablet/screens/upload_screen.dart';
import 'package:tablet/widgets/app_shell.dart';
import 'package:tablet/providers/auth_provider.dart';
import 'package:tablet/providers/upload_provider.dart';
import 'package:tablet/screens/splash_screen.dart';
import 'package:tablet/screens/chat_screen.dart';
import 'package:tablet/screens/qr_screen.dart';
import 'package:tablet/screens/notifications_screen.dart';
import 'package:tablet/screens/report_screen.dart';

const _dashboardPageKey = ValueKey('dashboard');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);


  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final status = ref.read(authProvider);
      final location = state.matchedLocation;

      switch (status) {
        case AuthStatus.unknown:
          return location == Routes.splash ? null : Routes.splash;
        case AuthStatus.unauthenticated:
          return location == Routes.login ? null : Routes.login;
        case AuthStatus.authenticated:
          if (location == Routes.login || location == Routes.splash) {
            return Routes.dashboard;
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // 대시보드
          GoRoute(
            path: Routes.dashboard,
            pageBuilder: (context, state) => const NoTransitionPage(
              key: _dashboardPageKey,
              child: DashboardScreen(selectedBatchId: null),
            ),
          ),
          GoRoute(
            path: Routes.batchPath,
            pageBuilder: (context, state) => NoTransitionPage(
              key: _dashboardPageKey, // ← 같은 키
              child: DashboardScreen(
                selectedBatchId: state.pathParameters['batchId'],
              ),
            ),
            routes: [
              GoRoute(
                path: Routes.reportSegment,
                builder: (context, state) =>
                    ReportScreen(batchId: state.pathParameters['batchId']!),
              ),
            ],
          ),
          GoRoute(
            path: Routes.upload,
            builder: (context, state) => const UploadScreen(),
            // 고르던 환자·파일을 두고 나가면 그대로 사라진다. 한 번 묻는다.
            onExit: (context, state) async {
              final upload = ref.read(uploadProvider);

              // 업로드 중 이탈은 막는다 — 배치만 만들어지고 이미지가 안 올라간다
              if (upload.busy) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('업로드가 끝난 뒤에 이동할 수 있습니다')),
                );
                return false;
              }
              // 분석 시작에 성공하면 reset()이 이미 불려 여기 걸리지 않는다
              if (upload.patient == null && upload.files.isEmpty) return true;

              final leave = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('작성 중인 분석이 있습니다'),
                  content: const Text('나가면 선택한 환자와 이미지가 사라집니다.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('머무르기'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('나가기'),
                    ),
                  ],
                ),
              );
              if (leave ?? false) {
                ref.read(uploadProvider.notifier).reset();
                return true;
              }
              return false;
            },
          ),
          GoRoute(
            // 사이드바에서는 뺐다(그 자리를 '새 분석'이 쓴다). 라우트는 남겨둔다 —
            // 서버에 /chat/firebase-token/ 이 이미 있어 Firestore 채팅이 붙을 자리다.
            path: Routes.chat,
            builder: (context, state) => const ChatScreen(),
          ),
          GoRoute(
            path: Routes.qr,
            builder: (context, state) => const QrScreen(),
          ),
          GoRoute(
            path: Routes.notifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('경로 없음: ${state.uri}'))),
  );
});
