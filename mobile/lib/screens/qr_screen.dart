import 'package:flutter/material.dart';
import '../services/qr_service.dart';

// TODO: 임시 스텁 — 실제 화면으로 교체 예정
class QrScreen extends StatelessWidget {
  final QrService qrService;
  const QrScreen({super.key, required this.qrService});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('QR 발급 (준비 중)')));
  }
}
