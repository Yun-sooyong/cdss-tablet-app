import 'package:flutter/material.dart';

/// VitaTree 공용 테마. mobile·tablet이 같이 쓴다.
///
/// ```dart
/// import 'package:shared/theme/theme.dart';
///
/// MaterialApp(theme: VitaTreeTheme.light, ...)
/// ```

// ─────────────────────────── 색 ───────────────────────────

/// 로고의 딥 틸그린이 액션 색([brand]), 브랜드 팔레트 5색은
/// 배경·보더 등 서포트 역할([sage100]~[sage600])이다.
///
/// 팔레트 5색은 전부 명도가 높아 주 버튼 색으로 쓸 수 없다. 가장 진한
/// `#8DA68A`도 흰 글씨 명암비가 2.6:1로 WCAG AA(4.5:1)에 못 미친다.
/// `#0B5D4E`는 7.8:1로 통과한다.
class AppColors {
  const AppColors._();

  // 브랜드 (로고)
  static const brand = Color(0xFF0B5D4E);
  static const brandDark = Color(0xFF084438); // pressed / hover
  static const brandSoft = Color(0xFFE6EFEA); // 선택 카드 배경, 배지
  static const onBrand = Color(0xFFFFFFFF);

  // 브랜드 팔레트 (세이지)
  static const sage600 = Color(0xFF8DA68A); // 보조 아이콘
  static const sage400 = Color(0xFFB0BFA8); // 구분선 강조
  static const sage300 = Color(0xFFB7BFAE); // 보더
  static const sage200 = Color(0xFFD3D9C7); // 연한 보더, 스켈레톤
  static const sage100 = Color(0xFFF2F1E4); // 앱 배경

  // 중성
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1A2420); // 본문
  static const inkMuted = Color(0xFF5A6660); // 보조 텍스트
  static const inkFaint = Color(0xFF8A948E); // 힌트, 자리표시자

  // 상태
  static const success = brand;
  static const warning = Color(0xFF8A6D1F);
  static const danger = Color(0xFFB3261E);
}

// ────────────────────────── 치수 ──────────────────────────

/// 버튼 모양이 화면마다 흔들리지 않도록 여기 값을 단일 출처로 삼는다.
/// 버튼과 입력창이 같은 [radius]·[controlHeight]를 공유한다.
class AppDimens {
  const AppDimens._();

  static const radius = 10.0; // 버튼·입력창 공통
  static const radiusLg = 16.0; // 카드·패널

  static const controlHeight = 48.0; // 태블릿 터치 타깃 최소치
  static const controlPaddingX = 20.0;

  static const gapSm = 8.0;
  static const gapMd = 12.0;
  static const gapLg = 16.0;
  static const gapXl = 24.0;
}

// ────────────────────────── 버튼 ──────────────────────────

/// 버튼 스타일 단일 출처.
///
/// 모양(높이·모서리·여백·글꼴)은 [_base]에서 한 번만 정하고 색만 바꾼다.
/// 새 종류를 추가할 때도 [_base]를 거치게 해야 모양이 흔들리지 않는다.
///
/// - [primary]   `FilledButton`   — 화면당 하나. '로그인 하기', '분석 시작'
/// - [secondary] `OutlinedButton` — 보조 액션. '공유', '취소'
/// - [tertiary]  `TextButton`     — 약한 액션. '아이디 발급 요청'
/// - [danger]    `FilledButton`   — 파괴적 액션. '삭제'
class AppButtonStyles {
  const AppButtonStyles._();

  static ButtonStyle _base({
    required Color foreground,
    Color? background,
    BorderSide? side,
  }) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.inkFaint
            : foreground,
      ),
      backgroundColor: background == null
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? AppColors.sage200
                  : background,
            ),
      side: side == null
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? const BorderSide(color: AppColors.sage200)
                  : side,
            ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return foreground.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return foreground.withValues(alpha: 0.08);
        }
        return null;
      }),
      // 너비는 내용에 맡기고 높이만 고정한다.
      minimumSize: const WidgetStatePropertyAll(
        Size(0, AppDimens.controlHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppDimens.controlPaddingX),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppDimens.radius)),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
      ),
      elevation: const WidgetStatePropertyAll(0),
      iconSize: const WidgetStatePropertyAll(18),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  static final ButtonStyle primary = _base(
    foreground: AppColors.onBrand,
    background: AppColors.brand,
  );

  static final ButtonStyle secondary = _base(
    foreground: AppColors.ink,
    background: AppColors.surface,
    side: const BorderSide(color: AppColors.sage300),
  );

  static final ButtonStyle tertiary = _base(foreground: AppColors.brand);

  static final ButtonStyle danger = _base(
    foreground: AppColors.onBrand,
    background: AppColors.danger,
  );
}

// ───────────────────────── ThemeData ─────────────────────────

class VitaTreeTheme {
  const VitaTreeTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brand).copyWith(
        primary: AppColors.brand,
        onPrimary: AppColors.onBrand,
        primaryContainer: AppColors.brandSoft,
        onPrimaryContainer: AppColors.brand,
        secondary: AppColors.sage600,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.inkMuted,
        outline: AppColors.sage300,
        outlineVariant: AppColors.sage200,
        error: AppColors.danger,
        onError: AppColors.onBrand,
      ),
      scaffoldBackgroundColor: AppColors.sage100,
      dividerTheme: const DividerThemeData(
        color: AppColors.sage200,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.ink, size: 22),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      // 버튼 4종이 모두 같은 모양을 쓴다.
      filledButtonTheme: FilledButtonThemeData(style: AppButtonStyles.primary),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppButtonStyles.secondary,
      ),
      textButtonTheme: TextButtonThemeData(style: AppButtonStyles.tertiary),
      // 기존 화면들이 ElevatedButton을 쓰고 있어 primary와 같은 모양으로 맞춘다.
      // 새 코드는 FilledButton을 쓸 것.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppButtonStyles.primary,
      ),

      // 입력창도 버튼과 같은 radius·보더를 쓴다. 나란히 놓였을 때 어긋나지 않도록.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.inkFaint),
        labelStyle: const TextStyle(color: AppColors.inkMuted),
        prefixIconColor: AppColors.inkFaint,
        suffixIconColor: AppColors.inkMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.gapLg,
          vertical: AppDimens.gapMd,
        ),
        border: _inputBorder(AppColors.sage300),
        enabledBorder: _inputBorder(AppColors.sage300),
        focusedBorder: _inputBorder(AppColors.brand, width: 1.5),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.5),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
