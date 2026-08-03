import '../models/reservation.dart';

class ReservationService {
  // 새 예약 폼에서 고를 수 있는 선택지 — 나중엔 병원 API에서 받아올 값들
  static const List<String> departments = ['내과', '정형외과', '피부과', '이비인후과'];
  static const List<String> doctors = ['김의사', '박의사', '이의사'];
  static const List<String> purposes = ['정기검진', '진료', '재진', '처방전 재발급'];
  static const List<String> documentTypes = [
    '처방전',
    '진단서',
    '진료확인서',
    '보험용 서류',
    '기타'
  ];

  final List<Reservation> _reservations = [
    Reservation(
        id: 'r1',
        dateTime: DateTime(2026, 8, 5, 14, 0),
        hospitalName: '서울내과',
        department: '내과',
        purpose: '정기검진',
        doctorName: '김의사',
        status: ReservationStatus.upcoming),
    Reservation(
        id: 'r2',
        dateTime: DateTime(2026, 7, 10, 10, 30),
        hospitalName: '서울내과',
        department: '내과',
        purpose: '진료',
        doctorName: '김의사',
        status: ReservationStatus.completed),
    Reservation(
        id: 'r3',
        dateTime: DateTime(2026, 7, 15, 11, 0),
        hospitalName: '서울내과',
        department: '내과',
        purpose: '서류 발급 · 진단서',
        doctorName: '김의사',
        status: ReservationStatus.completed),
  ];

  Future<List<Reservation>> fetchUpcoming() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _reservations.where((r) => r.isUpcoming).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<List<Reservation>> fetchPast() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _reservations.where((r) => !r.isUpcoming).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  Future<void> reschedule(String id, DateTime newDateTime) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final matches = _reservations.where((r) => r.id == id);
    if (matches.isNotEmpty) matches.first.dateTime = newDateTime;
  }

  Future<void> cancel(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final matches = _reservations.where((r) => r.id == id);
    if (matches.isNotEmpty) matches.first.status = ReservationStatus.canceled;
  }

  Future<void> requestNew({
    required DateTime dateTime,
    required String hospitalName,
    required String department,
    required String purpose,
    required String doctorName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _reservations.add(Reservation(
      id: 'r${_reservations.length + 1}',
      dateTime: dateTime,
      hospitalName: hospitalName,
      department: department,
      purpose: purpose,
      doctorName: doctorName,
    ));
  }

  // "서류 발급" 목적으로 신청한 예약만 모아서 최신순으로 반환 — 문서함 화면용.
  Future<List<Reservation>> fetchDocumentRequests() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final docs =
        _reservations.where((r) => r.purpose.startsWith('서류 발급')).toList();
    docs.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return docs;
  }
}
