import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    card: AppColors.lightCard,
    cardHover: AppColors.lightCardHover,
    divider: AppColors.lightDivider,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textDisabled: AppColors.lightTextDisabled,
    navBackground: AppColors.lightNavBackground,
    navSelected: AppColors.lightNavSelected,
    navInactive: AppColors.lightNavInactive,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    // 어두운 배경에서는 #01403A 가 안 보인다. 액션 색만 뒤집는다.
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    card: AppColors.darkCard,
    cardHover: AppColors.darkCard,
    divider: AppColors.darkDivider,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textDisabled: AppColors.darkTextDisabled,
    navBackground: AppColors.darkNavBackground,
    navSelected: AppColors.darkNavSelected,
    navInactive: AppColors.darkNavInactive,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color background,
    required Color surface,
    required Color card,
    required Color cardHover,
    required Color divider,
    required Color textPrimary,
    required Color textSecondary,
    required Color textDisabled,
    required Color navBackground,
    required Color navSelected,
    required Color navInactive,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: AppColors.secondary,
      onPrimaryContainer: onPrimary,
      secondary: AppColors.secondary,
      onSecondary: onPrimary,
      tertiary: AppColors.accent,
      onTertiary: onPrimary,
      // surface = 앱 배경. 사이드바처럼 한 단 올라간 면은 surfaceContainer 계열을 쓴다.
      surface: background,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: card,
      surfaceContainerLow: card,
      surfaceContainer: cardHover,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: surface,
      outline: divider,
      outlineVariant: divider,
      error: AppColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: card,
      dividerColor: divider,
      disabledColor: textDisabled,
      // fontFamily: 'Pretendard' — 폰트 에셋이 없어 제거했다.
      // ttf를 tablet/assets/fonts/ 에 넣고 pubspec에 선언하면 이 줄만 되살리면 된다.
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: TextStyle(color: textDisabled, fontSize: 11),
        // 카드 위에 붙는 작은 섹션 라벨 ('오늘 복용', '다음 예약' 패턴).
        // ⚠️ labelLarge는 Material 3에서 버튼 글씨라 쓰면 안 된다.
        titleSmall: TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      iconTheme: IconThemeData(color: textPrimary, size: 22),

      // 버튼 — 모양은 공유하되 높이 고정은 ElevatedButton에만 건다.
      // FilledButton에 minimumSize를 걸면 '+ 새 분석' 같은 인라인 버튼이 늘어난다.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(AppDimens.controlHeight),
          shape: _roundedShape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: divider,
          disabledForegroundColor: textDisabled,
          padding: _controlPadding,
          shape: _roundedShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          disabledForegroundColor: textDisabled,
          side: BorderSide(color: divider),
          padding: _controlPadding,
          shape: _roundedShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          disabledForegroundColor: textDisabled,
          padding: _controlPadding,
          shape: _roundedShape,
        ),
      ),

      // 카드는 그림자 없이 큰 라운드 + 아주 연한 테두리로만 구분한다.
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: BorderSide(color: divider),
        ),
      ),
      // 상태 태그는 작고 연한 pill. 목록의 주인공이 아니다.
      chipTheme: ChipThemeData(
        backgroundColor: background,
        // 선택 칩은 primary/onPrimary 짝으로 간다. secondary를 쓰면
        // 다크에서 어두운 배경 위에 어두운 글씨가 된다.
        selectedColor: primary,
        disabledColor: divider,
        side: BorderSide(color: divider),
        labelStyle: TextStyle(
          color: textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(color: onPrimary, fontSize: 12),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppDimens.gapSm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.gapSm,
          vertical: 6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.gapLg,
          vertical: AppDimens.gapSm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        iconColor: textSecondary,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: navBackground,
        // 선택 표시는 primary를 옅게 깔고 아이콘·라벨을 primary로 —
        // 진한 인디케이터 위에 글씨를 얹는 것보다 대비가 안전하다.
        indicatorColor: primary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: primary, size: 24),
        unselectedIconTheme: IconThemeData(color: navInactive, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(color: navInactive, fontSize: 12),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: TextStyle(color: textDisabled),
        labelStyle: TextStyle(color: textSecondary),
        floatingLabelStyle: TextStyle(color: primary),
        prefixIconColor: textDisabled,
        suffixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.gapLg,
          vertical: AppDimens.gapLg,
        ),
        border: _inputBorder(divider),
        enabledBorder: _inputBorder(divider),
        focusedBorder: _inputBorder(primary, width: 1.5),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 1.5),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: divider,
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
    );
  }

  static const _controlPadding = EdgeInsets.symmetric(
    horizontal: AppDimens.controlPaddingX,
    vertical: AppDimens.gapMd,
  );

  static final _roundedShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppDimens.radius),
  );

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
