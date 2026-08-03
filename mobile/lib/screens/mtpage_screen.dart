import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// TODO: 임시 스텁 — 실제 화면으로 교체 예정
class MyPageScreen extends StatelessWidget {
  final AuthService authService;
  const MyPageScreen({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('마이페이지 (준비 중)')));
  }
}
