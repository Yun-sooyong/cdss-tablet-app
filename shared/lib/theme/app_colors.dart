import 'package:flutter/material.dart';

/// V-Tree 브랜드 팔레트 (라이트 7색). 로고에서 뽑은 값이다.
///
/// ```
/// #F5F8FA  #E7EEF2  #D7E1E8  #A5B4AA  #598E6B  #2E6B4F  #01403A
/// ```
///
/// 밝은 셋은 쿨톤 뉴트럴(배경·카드·구분선), 어두운 셋은 브랜드 녹색이다.
/// [A5B4AA]는 그 사이를 잇는 중간값이라 비활성 텍스트에 쓴다.
class AppColors {
  AppColors._();

  // 브랜드 팔레트 — 이 7색이 전부다
  static const n100 = Color(0xFFF5F8FA); // 가장 밝음
  static const n200 = Color(0xFFE7EEF2);
  static const n300 = Color(0xFFD7E1E8);
  static const n400 = Color(0xFFA5B4AA);
  static const g500 = Color(0xFF598E6B);
  static const g700 = Color(0xFF2E6B4F);
  static const g900 = Color(0xFF01403A); // 로고 딥 틸그린

  // 라이트 모드 — 액션 색은 가장 진한 녹색.
  // #01403A 위 흰 글씨는 명암비 11.7:1 로 WCAG AAA를 넘는다.
  static const primary = g900;
  static const onPrimary = Colors.white;
  static const secondary = g700;
  static const accent = g500;

  static const lightBackground = n200;
  static const lightSurface = n300; // 사이드바처럼 한 단 올라간 면
  static const lightCard = n100; // 배경보다 밝아야 카드가 떠 보인다
  static const lightCardHover = n200;
  static const lightDivider = n300;
  static const lightTextPrimary = g900; // 배경 대비 11:1
  static const lightTextSecondary = g700; // 배경 대비 5.9:1
  static const lightTextDisabled = n400;

  // 다크 모드 — 전달받은 값 그대로다. 라이트 7색 팔레트에는 다크 대응값이
  // 없어서 이쪽은 손대지 않았다.
  //
  // 액션 색만 뒤집는다: #01403A 는 어두운 배경에서 안 보인다.
  // #A5B4AA 위 #01403A 는 5.4:1 로 AA를 통과한다.
  static const darkPrimary = n400;
  static const darkOnPrimary = g900;

  static const darkBackground = Color(0xFF2E3A36);
  static const darkSurface = Color(0xFF384445);
  static const darkCard = Color(0xFF4A5A53);
  static const darkDivider =
      Color(0xFF4E5A53); // ⚠️ 목업에서 읽은 값이 이상해서 임시값 — 확인 후 교체
  static const darkTextPrimary = Color(0xFFE7EAE6);
  static const darkTextSecondary = Color(0xFFC5CEC5);
  static const darkTextDisabled = Color(0xFF8D9A93);

  // 상태색 — 라이트/다크 공통. 위젯에서 직접 참조해도 안전하다.
  static const success = g500;
  static const info = Color(0xFF5B8DA9);
  static const warning = Color(0xFFD7A64B);
  static const error = Color(0xFFC96767);

  // 네비게이션
  static const lightNavBackground = lightSurface;
  static const lightNavSelected = accent;
  static const lightNavInactive = lightTextDisabled;
  static const darkNavBackground = darkSurface;
  static const darkNavSelected = accent;
  static const darkNavInactive = darkTextDisabled;
}
