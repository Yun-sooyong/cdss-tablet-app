import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/providers/auth_provider.dart';
import 'package:tablet/push/push_service.dart';
import 'package:tablet/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // google-services.json 이 없으면 실패하지만 앱은 그대로 뜬다 (푸시만 비활성)
  await PushController.initFirebase();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FCM 토큰 등록은 인증이 필요하다. 로그인된 뒤에 붙인다.
    // auth_provider가 push를 직접 부르면 import 순환이 생겨 여기서 연결한다.
    ref.listen(authProvider, (prev, next) {
      if (next == AuthStatus.authenticated) {
        ref.read(pushProvider.notifier).register();
      }
    });

    return MaterialApp.router(
      title: 'VitaTree',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
