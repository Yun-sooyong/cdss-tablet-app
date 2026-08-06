import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'services/theme_controller.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'utils/app_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const PatientApp());
}

class PatientApp extends StatefulWidget {
  const PatientApp({super.key});

  @override
  State<PatientApp> createState() => _PatientAppState();
}

class _PatientAppState extends State<PatientApp> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    ThemeController.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'V-Tree',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: SplashScreen(authService: _authService),
        );
      },
    );
  }
}
