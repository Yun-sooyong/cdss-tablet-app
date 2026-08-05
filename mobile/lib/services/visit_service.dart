<<<<<<< HEAD
import '../models/visit.dart';
=======
import 'dart:convert';
import '../models/visit.dart';
import 'api_client.dart';
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

enum VisitSearchField { all, memo, department }

class VisitService {
<<<<<<< HEAD
  final List<Visit> _visits = [
    Visit(
        id: 'v1',
        date: DateTime(2026, 7, 20),
        department: '내과',
        memo: '고혈압 정기 검진',
        doctorName: '김의사'),
    Visit(
        id: 'v2',
        date: DateTime(2026, 6, 15),
        department: '내과',
        memo: '약 처방 변경',
        doctorName: '김의사'),
    Visit(
        id: 'v3',
        date: DateTime(2026, 5, 2),
        department: '내과',
        memo: '초진',
        doctorName: '김의사'),
  ];
=======
  final _client = ApiClient.instance;

  Future<List<Visit>> _fetchAll() async {
    final res = await _client.get('/api/v1/patients/me/visits/');
    if (res.statusCode != 200) throw Exception('진료내역을 불러오지 못했어요.');
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((v) => Visit.fromJson(v as Map<String, dynamic>)).toList();
  }
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d

  Future<List<Visit>> fetchVisits({
    String? query,
    VisitSearchField field = VisitSearchField.memo,
    DateTime? onDate,
  }) async {
<<<<<<< HEAD
    await Future.delayed(const Duration(milliseconds: 300));
    var result = List<Visit>.from(_visits);
=======
    var result = await _fetchAll();
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
    if (query != null && query.isNotEmpty) {
      result = result.where((v) {
        switch (field) {
          case VisitSearchField.all:
            return v.memo.contains(query) || v.department.contains(query);
          case VisitSearchField.memo:
            return v.memo.contains(query);
          case VisitSearchField.department:
            return v.department.contains(query);
        }
      }).toList();
    }
    if (onDate != null) {
      result = result
          .where((v) =>
              v.date.year == onDate.year &&
              v.date.month == onDate.month &&
              v.date.day == onDate.day)
          .toList();
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  Future<Set<DateTime>> fetchVisitDates() async {
<<<<<<< HEAD
    await Future.delayed(const Duration(milliseconds: 150));
    return _visits
=======
    final visits = await _fetchAll();
    return visits
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
        .map((v) => DateTime(v.date.year, v.date.month, v.date.day))
        .toSet();
  }

<<<<<<< HEAD
// 재진 선택 시 "저번 방문 기록" 미리보기용. department가 있으면 그 과 안에서만,
// 없으면 전체에서 가장 최근 방문 1건을 찾는다.
=======
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  Future<Visit?> fetchLatestVisit({String? department}) async {
    final visits = await fetchVisits();
    final sorted = [...visits]..sort((a, b) => b.date.compareTo(a.date));
    if (department != null) {
      final matched = sorted.where((v) => v.department == department);
      return matched.isNotEmpty ? matched.first : null;
    }
    return sorted.isNotEmpty ? sorted.first : null;
  }
}
