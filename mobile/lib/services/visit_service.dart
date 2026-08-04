import 'dart:convert';
import '../models/visit.dart';
import 'api_client.dart';

enum VisitSearchField { all, memo, department }

class VisitService {
  final _client = ApiClient.instance;

  Future<List<Visit>> _fetchAll() async {
    final res = await _client.get('/api/v1/patients/me/visits/');
    if (res.statusCode != 200) throw Exception('진료내역을 불러오지 못했어요.');
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((v) => Visit.fromJson(v as Map<String, dynamic>)).toList();
  }

  Future<List<Visit>> fetchVisits({
    String? query,
    VisitSearchField field = VisitSearchField.memo,
    DateTime? onDate,
  }) async {
    var result = await _fetchAll();
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
    final visits = await _fetchAll();
    return visits
        .map((v) => DateTime(v.date.year, v.date.month, v.date.day))
        .toSet();
  }

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
