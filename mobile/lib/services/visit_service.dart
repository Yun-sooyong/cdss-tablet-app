import '../models/visit.dart';

class VisitService {
  final List<Visit> _visits = [
    Visit(
      id: 'v1',
      date: DateTime(2026, 7, 20),
      department: '내과',
      memo: '고혈압 정기 검진',
      doctorName: '김의사',
    ),
    Visit(
      id: 'v2',
      date: DateTime(2026, 6, 15),
      department: '내과',
      memo: '약 처방 변경',
      doctorName: '김의사',
    ),
    Visit(
      id: 'v3',
      date: DateTime(2026, 5, 2),
      department: '내과',
      memo: '초진',
      doctorName: '김의사',
    ),
  ];

  Future<List<Visit>> fetchVisits({String? query, DateTime? onDate}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var result = List<Visit>.from(_visits);
    if (query != null && query.isNotEmpty) {
      result = result
          .where((v) => v.memo.contains(query) || v.department.contains(query))
          .toList();
    }
    if (onDate != null) {
      result = result
          .where(
            (v) =>
                v.date.year == onDate.year &&
                v.date.month == onDate.month &&
                v.date.day == onDate.day,
          )
          .toList();
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }
}
