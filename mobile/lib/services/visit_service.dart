import '../models/visit.dart';

enum VisitSearchField { all, memo, department }

class VisitService {
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

  Future<List<Visit>> fetchVisits({
    String? query,
    VisitSearchField field = VisitSearchField.memo,
    DateTime? onDate,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var result = List<Visit>.from(_visits);
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
    await Future.delayed(const Duration(milliseconds: 150));
    return _visits
        .map((v) => DateTime(v.date.year, v.date.month, v.date.day))
        .toSet();
  }

// 재진 선택 시 "저번 방문 기록" 미리보기용. department가 있으면 그 과 안에서만,
// 없으면 전체에서 가장 최근 방문 1건을 찾는다.
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
