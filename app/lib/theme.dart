import 'package:flutter/material.dart';

import 'widgets/card_style.dart';

class AppColors {
  static const green = CardColors.green;
  static const greenDark = CardColors.greenDark;
  static const ink = Color(0xFF1F2328);
  static const muted = Color(0xFF8A9099);
  static const line = Color(0xFFE8EAED);
  static const field = Color(0xFFF5F6F8);
  static const warn = Color(0xFFE8A13A);
  static const error = Color(0xFFE5484D);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    primary: AppColors.greenDark,
    surface: Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.greenDark),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(color: AppColors.greenDark),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.green, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.greenDark,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
