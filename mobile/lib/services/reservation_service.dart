<<<<<<< HEAD
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
=======
import 'dart:convert';
import '../models/department.dart';
import '../models/reservation.dart';
import 'api_client.dart';

class ReservationService {
  final _client = ApiClient.instance;

  static const List<String> documentTypes = [
    '처방전', '진단서', '진료확인서', '보험용 서류', '기타'
  ];

  List<Department>? _departmentsCache;

  // 진료과 목록은 자주 안 바뀌니까 한 번 받아오면 메모리에 캐싱해서 재사용.
  // 그래서 예약 목록 화면 새로고침할 때마다 이 API를 또 부르지 않아.
  Future<List<Department>> fetchDepartments() async {
    if (_departmentsCache != null) return _departmentsCache!;
    final res = await _client.get('/api/v1/departments/');
    if (res.statusCode != 200) throw Exception('진료과 목록을 불러오지 못했어요.');
    final data = jsonDecode(res.body) as List<dynamic>;
    _departmentsCache =
        data.map((d) => Department.fromJson(d as Map<String, dynamic>)).toList();
    return _departmentsCache!;
  }

  ReservationStatus _statusFromString(String s) {
    switch (s) {
      case 'REQUESTED':
        return ReservationStatus.requested;
      case 'CONFIRMED':
        return ReservationStatus.confirmed;
      case 'CHANGED':
        return ReservationStatus.changed;
      case 'CANCELED':
        return ReservationStatus.canceled;
      case 'NO_SHOW':
        return ReservationStatus.noShow;
      default:
        return ReservationStatus.requested;
    }
  }

  Future<List<Reservation>> _fetchAll() async {
    final departments = await fetchDepartments();
    final nameByCode = {for (final d in departments) d.code: d.name};

    final res = await _client.get('/api/v1/patients/me/reservations/');
    if (res.statusCode != 200) throw Exception('예약 목록을 불러오지 못했어요.');
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((r) {
      final json = r as Map<String, dynamic>;
      final code = json['department'] as String;
      return Reservation(
        id: json['id'] as String,
        dateTime: DateTime.parse(json['scheduled_at'] as String),
        hospitalName: '서울내과',
        department: nameByCode[code] ?? code,
        purpose: '',
        doctorName: json['staff'] != null ? '배정됨' : '배정 예정',
        status: _statusFromString(json['status'] as String),
      );
    }).toList();
  }

  Future<List<Reservation>> fetchUpcoming() async {
    final all = await _fetchAll();
    return all.where((r) => r.isUpcoming).toList()
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<List<Reservation>> fetchPast() async {
<<<<<<< HEAD
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
=======
    final all = await _fetchAll();
    return all.where((r) => !r.isUpcoming).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  Future<void> reschedule(String id, DateTime newDateTime,
      {String? changeReason}) async {
    final body = <String, dynamic>{
      'scheduled_at': newDateTime.toIso8601String(),
    };
    if (changeReason != null && changeReason.isNotEmpty) {
      body['change_reason'] = changeReason;
    }
    final res = await _client.patch('/api/v1/reservations/$id/', body: body);
    if (res.statusCode != 200) throw Exception('일정 변경에 실패했어요.');
  }

  Future<void> cancel(String id) async {
    final res = await _client.delete('/api/v1/reservations/$id/');
    if (res.statusCode != 200) throw Exception('예약 취소에 실패했어요.');
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  }

  Future<void> requestNew({
    required DateTime dateTime,
    required String hospitalName,
<<<<<<< HEAD
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
=======
    required String department, // 화면에서 고른 진료과 '이름' (예: '내과')
    required String purpose,
  }) async {
    final departments = await fetchDepartments();
    final match = departments.where((d) => d.name == department);
    if (match.isEmpty) {
      throw Exception('$department의 진료과 코드를 찾을 수 없어요.');
    }
    final res = await _client.post('/api/v1/patients/me/reservations/', body: {
      'department': match.first.code,
      'scheduled_at': dateTime.toIso8601String(),
    });
    if (res.statusCode != 201) throw Exception('예약 신청에 실패했어요.');
  }
}
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
