import 'package:flutter_test/flutter_test.dart';
import 'package:tablet/data/analysis_repository.dart';

/// GCS 서명 URL은 `X-Goog-SignedHeaders: content-type;host` 로 서명된다.
/// 앱이 보내는 Content-Type이 서버가 서명할 때 쓴 값과 다르면
/// 업로드가 403 SignatureDoesNotMatch 로 조용히 실패한다.
///
/// 아래 기대값은 배포 서버(2026-08-05)에 실제로 PUT 해보고 확인한 값이다.
/// 서버가 MIME 추론 방식을 바꾸면 이 테스트가 먼저 깨져야 한다.
void main() {
  group('업로드 Content-Type은 서버 서명과 일치해야 한다', () {
    const cases = {
      'slide.png': 'image/png',
      'slide.jpg': 'image/jpeg',
      'slide.jpeg': 'image/jpeg',
      'slide.tif': 'image/tiff',
      'slide.tiff': 'image/tiff',
      // 서버가 모르는 확장자는 octet-stream 으로 서명한다
      'slide.svs': 'application/octet-stream',
      'noextension': 'application/octet-stream',
    };

    cases.forEach((filename, expected) {
      test('$filename -> $expected', () {
        expect(HttpAnalysisRepository.contentTypeFor(filename), expected);
      });
    });

    test('대문자 확장자도 같게 취급한다', () {
      expect(HttpAnalysisRepository.contentTypeFor('SLIDE.PNG'), 'image/png');
    });
  });
}
