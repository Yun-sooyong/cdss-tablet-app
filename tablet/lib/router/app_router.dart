import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tablet/router/routes.dart';
import 'package:tablet/screens/dashboard_screen.dart';
import 'package:tablet/screens/login_screen.dart';
import 'package:tablet/screens/result_detail_screen.dart';
import 'package:tablet/screens/result_screen.dart';
import 'package:tablet/screens/upload_screen.dart';
import 'package:tablet/widgets/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: Routes.dashboard,
  debugLogDiagnostics: true, // 어떤 경로로 이동했는지 콘솔에 찍힘
  routes: [
    GoRoute(
      path: Routes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: Routes.dashboard,
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: Routes.upload,
          builder: (context, state) => const UploadScreen(),
        ),
        GoRoute(
          path: Routes.results,
          builder: (context, state) => const ResultScreen(),
        ),
        GoRoute(
          path: Routes.resultDetail,
          builder: (context, state) => const ResultDetailScreen(),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text('경로 없음: ${state.uri}'))),
);
