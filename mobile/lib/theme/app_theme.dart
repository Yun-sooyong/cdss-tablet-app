import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        card: AppColors.lightCard,
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
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        card: AppColors.darkCard,
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
    required Color background,
    required Color surface,
    required Color card,
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
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: textPrimary,
      surface: surface,
      onSurface: textPrimary,
      error: AppColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardColor: card,
      dividerColor: divider,
      disabledColor: textDisabled,
      fontFamily: 'Pretendard',
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBackground,
        selectedItemColor: navSelected,
        unselectedItemColor: navInactive,
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1),
    );
  }
}
