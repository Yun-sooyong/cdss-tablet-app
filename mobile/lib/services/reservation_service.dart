import 'dart:convert';
import '../models/reservation.dart';
import 'api_client.dart';

class ReservationService {
  final _client = ApiClient.instance;

  static const Map<String, String> departmentCodes = {
    '내과': 'IM',
    '정형외과': 'OS',
  };
  static const List<String> departments = ['내과', '정형외과'];
  static const List<String> documentTypes = [
    '처방전', '진단서', '진료확인서', '보험용 서류', '기타'
  ];

  String _departmentName(String code) {
    final entry = departmentCodes.entries.firstWhere(
      (e) => e.value == code,
      orElse: () => MapEntry(code, code),
    );
    return entry.key;
  }

  ReservationStatus _statusFromString(String s) {
    switch (s) {
      case 'REQUESTED': return ReservationStatus.requested;
      case 'CONFIRMED': return ReservationStatus.confirmed;
      case 'CHANGED': return ReservationStatus.changed;
      case 'CANCELED': return ReservationStatus.canceled;
      case 'NO_SHOW': return ReservationStatus.noShow;
      default: return ReservationStatus.requested;
    }
  }

  Reservation _fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] as String,
      dateTime: DateTime.parse(json['scheduled_at'] as String),
      hospitalName: '서울내과',
      department: _departmentName(json['department'] as String),
      purpose: '',
      doctorName: json['staff'] != null ? '배정됨' : '배정 예정',
      status: _statusFromString(json['status'] as String),
    );
  }

  Future<List<Reservation>> _fetchAll() async {
    final res = await _client.get('/api/v1/patients/me/reservations/');
    if (res.statusCode != 200) throw Exception('예약 목록을 불러오지 못했어요.');
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((r) => _fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<Reservation>> fetchUpcoming() async {
    final all = await _fetchAll();
    return all.where((r) => r.isUpcoming).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<List<Reservation>> fetchPast() async {
    final all = await _fetchAll();
    return all.where((r) => !r.isUpcoming).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  Future<void> reschedule(String id, DateTime newDateTime) async {
    final res = await _client.patch('/api/v1/reservations/$id/', body: {
      'scheduled_at': newDateTime.toIso8601String(),
    });
    if (res.statusCode != 200) throw Exception('일정 변경에 실패했어요.');
  }

  Future<void> cancel(String id) async {
    final res = await _client.delete('/api/v1/reservations/$id/');
    if (res.statusCode != 200) throw Exception('예약 취소에 실패했어요.');
  }

  Future<void> requestNew({
    required DateTime dateTime,
    required String hospitalName,
    required String department,
    required String purpose,
  }) async {
    final deptCode = departmentCodes[department];
    if (deptCode == null) {
      throw Exception('$department의 진료과 코드가 아직 등록되지 않았어요.');
    }
    final res = await _client.post('/api/v1/patients/me/reservations/', body: {
      'department': deptCode,
      'scheduled_at': dateTime.toIso8601String(),
    });
    if (res.statusCode != 201) throw Exception('예약 신청에 실패했어요.');
  }
}
