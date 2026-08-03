import 'package:flutter/material.dart';
import '../models/reservation.dart';

class DocumentDetailScreen extends StatelessWidget {
  final Reservation reservation;

  const DocumentDetailScreen({super.key, required this.reservation});

  String _statusLabel(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.upcoming:
        return '접수됨';
      case ReservationStatus.completed:
        return '발급 완료';
      case ReservationStatus.canceled:
        return '취소됨';
      default:
        return '알 수 없음';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = reservation.purpose.replaceFirst('서류 발급 · ', '');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(label: '문서 종류', value: title),
                    _DetailRow(
                      label: '신청일',
                      value:
                          '${reservation.dateTime.year}.${reservation.dateTime.month}.${reservation.dateTime.day}',
                    ),
                    _DetailRow(label: '병원', value: reservation.hospitalName),
                    _DetailRow(label: '진료과', value: reservation.department),
                    _DetailRow(label: '담당의', value: reservation.doctorName),
                    _DetailRow(
                        label: '상태', value: _statusLabel(reservation.status)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined),
                label: const Text('문서 다운로드'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('문서 다운로드 기능은 아직 준비 중이에요.')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
