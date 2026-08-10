import 'package:flutter/material.dart';

// V-Tree 컬러 팔레트. 라이트/다크에서 브랜드 컬러(primary 등)까지 값이 달라지므로
// 공유 상수가 아니라 라이트/다크로 완전히 분리해서 관리한다.
// 실제 화면에서는 이 값을 직접 참조하지 말고 app_theme.dart가 감싼
// Theme.of(context).colorScheme / AppStatusColors를 통해 접근한다.
class AppColors {
  AppColors._();

  // 라이트 모드
  static const lightPrimary = Color(0xFF8DA68A);
  static const lightPrimaryDark = Color(0xFF799574);
  static const lightPrimaryLight = Color(0xFFB6C8B2);
  static const lightAccent = Color(0xFFA8BE9C);
  static const lightBackground = Color(0xFFFBFAF5);
  static const lightCard = Color(0xFFF6F4EE);
  static const lightSecondaryBg = Color(0xFFEEF2EA);
  static const lightBorder = Color(0xFFDDE4D8);
  static const lightDivider = Color(0xFFE9ECE4);
  static const lightTextPrimary = Color(0xFF2D2F2C);
  static const lightTextSecondary = Color(0xFF7F857C);
  static const lightTextDisabled = Color(0xFFC7CEC2);
  static const lightSuccess = Color(0xFF6EA16B);
  static const lightWarning = Color(0xFFD9B86A);
  static const lightError = Color(0xFFC97B7B);
  static const lightGradient = [lightPrimary, lightPrimaryLight];

  // 다크 모드
  static const darkPrimary = Color(0xFFA9C0A2);
  static const darkPrimaryDark = Color(0xFF8DA68A);
  static const darkPrimaryLight = Color(0xFF6E8F6D);
  static const darkAccent = Color(0xFF94B28E);
  static const darkBackground = Color(0xFF232823);
  static const darkCard = Color(0xFF2D342D);
  static const darkSecondaryBg = Color(0xFF394139);
  static const darkBorder = Color(0xFF465046);
  static const darkDivider = Color(0xFF545E52);
  static const darkTextPrimary = Color(0xFFF4F3ED);
  static const darkTextSecondary = Color(0xFFC8CDC3);
  static const darkTextDisabled = Color(0xFF8D9389);
  static const darkSuccess = Color(0xFF89B383);
  static const darkWarning = Color(0xFFE0C16E);
  static const darkError = Color(0xFFE27D7D);
  static const darkGradient = [darkPrimary, darkPrimaryLight];
}

// ColorScheme에 없는 상태색(성공/경고)을 테마로 실어 나르기 위한 확장.
// 사용법: Theme.of(context).extension<AppStatusColors>()!.success
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  final Color success;
  final Color warning;

  const AppStatusColors({required this.success, required this.warning});

  @override
  AppStatusColors copyWith({Color? success, Color? warning}) {
    return AppStatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
