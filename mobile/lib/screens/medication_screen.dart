import 'package:flutter/material.dart';
import '../services/medication_service.dart';

// TODO: 임시 스텁 — 실제 화면으로 교체 예정
class MedicationScreen extends StatelessWidget {
  final MedicationService medicationService;
  const MedicationScreen({super.key, required this.medicationService});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('약 관리 (준비 중)')));
  }
}
