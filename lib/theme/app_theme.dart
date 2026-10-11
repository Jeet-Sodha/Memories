import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// All colors live here. To switch to Stitch's exact Midnight background,
/// change [background] to Color(0xFF131318).
class AppColors {
  static const background = Color(0xFF090B12);
  static const surface = Color(0xFF151923);
  static const card = Color(0xFF1C2230);
  static const elevated = Color(0xFF242B3A);
  static const textPrimary = Color(0xFFF4F4F5);
  static const textSecondary = Color(0xFF9296A3);
  static const accent = Color(0xFF8B91E8); // periwinkle
  static const accentLight = Color(0xFFBEC2FF); // text / icons on dark
  static const onAccent = Color(0xFF1F2578);
  static const memory = Color(0xFFE47C7C); // coral
  static const location = Color(0xFF8FAE9A); // sage
  static const error = Color(0xFFFFB4AB);
  static const line = Color(0x1FFFFFFF);
  static const scrim = Color(0xCC090B12);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
      }),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.memory,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevated,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        counterStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 1),
        ),
      ),
    );
  }
}
