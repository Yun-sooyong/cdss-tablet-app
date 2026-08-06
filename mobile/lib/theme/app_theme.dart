import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        primary: AppColors.lightPrimary,
        primaryContainer: AppColors.lightPrimaryLight,
        secondary: AppColors.lightAccent,
        tertiary: AppColors.lightPrimaryDark,
        background: AppColors.lightBackground,
        surface: AppColors.lightCard,
        surfaceVariant: AppColors.lightSecondaryBg,
        outline: AppColors.lightBorder,
        outlineVariant: AppColors.lightDivider,
        textPrimary: AppColors.lightTextPrimary,
        textSecondary: AppColors.lightTextSecondary,
        textDisabled: AppColors.lightTextDisabled,
        error: AppColors.lightError,
        success: AppColors.lightSuccess,
        warning: AppColors.lightWarning,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        primary: AppColors.darkPrimary,
        primaryContainer: AppColors.darkPrimaryLight,
        secondary: AppColors.darkAccent,
        tertiary: AppColors.darkPrimaryDark,
        background: AppColors.darkBackground,
        surface: AppColors.darkCard,
        surfaceVariant: AppColors.darkSecondaryBg,
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.darkDivider,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
        textDisabled: AppColors.darkTextDisabled,
        error: AppColors.darkError,
        success: AppColors.darkSuccess,
        warning: AppColors.darkWarning,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color primaryContainer,
    required Color secondary,
    required Color tertiary,
    required Color background,
    required Color surface,
    required Color surfaceVariant,
    required Color outline,
    required Color outlineVariant,
    required Color textPrimary,
    required Color textSecondary,
    required Color textDisabled,
    required Color error,
    required Color success,
    required Color warning,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: textPrimary,
      secondary: secondary,
      onSecondary: textPrimary,
      tertiary: tertiary,
      onTertiary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: textSecondary,
      outline: outline,
      outlineVariant: outlineVariant,
      error: error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardColor: surface,
      dividerColor: outlineVariant,
      disabledColor: textDisabled,
      fontFamily: 'Pretendard',
      extensions: [AppStatusColors(success: success, warning: warning)],
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
        titleLarge: TextStyle(
            color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(
            color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(color: textDisabled, fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
      ),
      dividerTheme: DividerThemeData(color: outlineVariant, thickness: 1),
    );
  }
}
