import 'package:flutter_test/flutter_test.dart';
import 'package:tablet/data/analysis_repository.dart';

/// 서버가 목록 엔드포인트를 하나씩 페이지네이션으로 옮기고 있다.
/// 2026-08-05 기준 `/analysis/batches/` 만 `{count, limit, offset, results}` 이고
/// 나머지(`model-versions`·`notifications`·`staff`·`shares`·`patients/search`)는
/// 아직 배열이다. 어느 쪽이 와도 깨지지 않아야 한다.
void main() {
  group('목록 응답은 배열과 페이지네이션을 모두 받아들인다', () {
    test('배열을 그대로 돌려준다', () {
      expect(HttpAnalysisRepository.itemsOf([1, 2, 3]), [1, 2, 3]);
    });

    test('페이지네이션이면 results를 꺼낸다', () {
      final body = {
        'count': 18,
        'limit': 50,
        'offset': 0,
        'results': [1, 2],
      };
      expect(HttpAnalysisRepository.itemsOf(body), [1, 2]);
    });

    test('빈 결과도 처리한다', () {
      expect(HttpAnalysisRepository.itemsOf({'count': 0, 'results': []}), []);
      expect(HttpAnalysisRepository.itemsOf([]), []);
    });

    test('알 수 없는 형식이면 던진다 — 조용히 빈 목록이 되면 안 된다', () {
      expect(
        () => HttpAnalysisRepository.itemsOf({'detail': 'nope'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => HttpAnalysisRepository.itemsOf(null),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('전체 개수', () {
    test('페이지네이션이면 count', () {
      expect(HttpAnalysisRepository.totalOf({'count': 18, 'results': []}), 18);
    });

    test('배열이면 null — 더 받아올 페이지가 없다는 뜻', () {
      expect(HttpAnalysisRepository.totalOf([1, 2]), isNull);
    });
  });
}
