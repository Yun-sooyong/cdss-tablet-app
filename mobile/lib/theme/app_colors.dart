import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 브랜드 — 라이트/다크 공통, 안 바뀜
  static const primary = Color(0xFF8DA68A);
  static const secondary = Color(0xFFB0BFA8);
  static const accent = Color(0xFFB7BFAE);

  // 라이트 모드
  static const lightSurface = Color(0xFFD3D9C7);
  static const lightBackground = Color(0xFFFBF9F1);
  static const lightCard = Color(0xFFF7F4E8);
  static const lightCardHover = Color(0xFFF3F0E7);
  static const lightDivider = Color(0xFFE5E0D2);
  static const lightTextPrimary = Color(0xFF2E3A33);
  static const lightTextSecondary = Color(0xFF5E6B60);
  static const lightTextDisabled = Color(0xFFA2AEA4);

  // 다크 모드
  static const darkBackground = Color(0xFF2E3A36);
  static const darkSurface = Color(0xFF384445);
  static const darkCard = Color(0xFF4A5A53);
  static const darkDivider =
      Color(0xFF4E5A53); // ⚠️ 목업에서 읽은 값이 이상해서 임시값 — 확인 후 교체
  static const darkTextPrimary = Color(0xFFE7EAE6);
  static const darkTextSecondary = Color(0xFFC5CEC5);
  static const darkTextDisabled = Color(0xFF8D9A93);

  // 상태색 — 라이트/다크 공통
  static const success = Color(0xFF5D8F66);
  static const info = Color(0xFF5B8DA9);
  static const warning = Color(0xFFD7A64B);
  static const error = Color(0xFFC96767);

  // 네비게이션
  static const lightNavBackground = lightSurface;
  static const lightNavSelected = secondary;
  static const lightNavInactive = lightTextDisabled;
  static const darkNavBackground = darkSurface;
  static const darkNavSelected = secondary;
  static const darkNavInactive = darkTextDisabled;
}
