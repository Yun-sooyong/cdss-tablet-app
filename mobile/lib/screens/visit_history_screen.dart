import 'package:flutter/material.dart';
import '../services/visit_service.dart';

// TODO: 임시 스텁 — 실제 화면으로 교체 예정
class VisitHistoryScreen extends StatelessWidget {
  final VisitService visitService;
  const VisitHistoryScreen({super.key, required this.visitService});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('진료내역 (준비 중)')));
  }
}
