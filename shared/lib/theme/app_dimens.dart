/// 간격·모서리 값의 단일 출처.
///
/// 버튼과 입력창이 같은 [radius]·[controlHeight]를 공유해서
/// 나란히 놓였을 때 어긋나지 않게 한다.
class AppDimens {
  const AppDimens._();

  static const radius = 12.0; // 버튼·입력창 공통
  static const radiusLg = 16.0; // 카드·패널
  static const radiusPill = 999.0; // 상태 태그

  static const controlHeight = 48.0; // 태블릿 터치 타깃 최소치
  static const controlPaddingX = 20.0;

  /// 카드 안쪽 여백. 모바일 디자인의 넉넉한 호흡을 그대로 쓴다.
  static const cardPadding = 20.0;

  static const gapSm = 8.0;
  static const gapMd = 12.0;
  static const gapLg = 16.0;
  static const gapXl = 24.0;
  static const gapXxl = 32.0;
}
