import 'package:flutter/material.dart';
import '../services/reservation_service.dart';

// TODO: 임시 스텁 — 실제 화면으로 교체 예정
class ReservationScreen extends StatelessWidget {
  final ReservationService reservationService;
  const ReservationScreen({super.key, required this.reservationService});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('예약 관리 (준비 중)')));
  }
}
