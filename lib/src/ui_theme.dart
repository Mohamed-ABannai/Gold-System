import 'package:flutter/material.dart';

class AppColors {
  static const ice = Color(0xFFF4FBFF);
  static const iceStrong = Color(0xFFE4F5FF);
  static const blue = Color(0xFF1F8BCB);
  static const ink = Color(0xFF142533);
  static const muted = Color(0xFF6D8291);
  static const border = Color(0xFFD6ECF8);
  static const success = Color(0xFF17A673);
  static const danger = Color(0xFFD94A4A);
}

ThemeData buildGoldTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    brightness: Brightness.light,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.ice,
    fontFamily: 'Arial',
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: AppColors.muted,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: AppColors.muted,
        letterSpacing: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.blue, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.blue,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      selectedIconTheme: IconThemeData(color: AppColors.blue),
      selectedLabelTextStyle: TextStyle(
        color: AppColors.blue,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: AppColors.muted,
        letterSpacing: 0,
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.iceStrong),
      dataRowColor: WidgetStateProperty.all(Colors.white),
      headingTextStyle: const TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      dataTextStyle: const TextStyle(color: AppColors.ink, letterSpacing: 0),
    ),
  );
}
