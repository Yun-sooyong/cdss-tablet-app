import '../models/reservation.dart';

class ReservationService {
  final List<Reservation> _reservations = [
    Reservation(
      id: 'r1',
      dateTime: DateTime(2026, 8, 5, 14, 0),
      hospitalName: '서울내과',
      purpose: '정기검진',
      doctorName: '김의사',
      status: ReservationStatus.upcoming,
    ),
    Reservation(
      id: 'r2',
      dateTime: DateTime(2026, 7, 10, 10, 30),
      hospitalName: '서울내과',
      purpose: '진료',
      doctorName: '김의사',
      status: ReservationStatus.completed,
    ),
  ];

  Future<List<Reservation>> fetchUpcoming() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _reservations.where((r) => r.isUpcoming).toList();
  }

  Future<List<Reservation>> fetchPast() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _reservations.where((r) => !r.isUpcoming).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  Future<void> reschedule(String id, DateTime newDateTime) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO: 실시간 슬롯 연동 없음 — 서버 붙으면 "요청 접수" 수준으로 처리
  }

  Future<void> cancel(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final r = _reservations.where((r) => r.id == id);
    if (r.isNotEmpty) r.first.status = ReservationStatus.canceled;
  }

  Future<void> requestNew({
    required DateTime dateTime,
    required String hospitalName,
    required String purpose,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
