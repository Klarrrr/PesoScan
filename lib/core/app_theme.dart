import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Font family names (declared in pubspec.yaml).
class AppFonts {
  AppFonts._();
  static const heading = 'Outfit';
  static const body = 'Inter';
  static const mono = 'JetBrainsMono';
}

/// Small helper for the monospaced money style used all over the prototype
/// (totals, prices, version tag).
class AppText {
  AppText._();

  static TextStyle mono({
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(PesoColors.light, Brightness.light);
  static ThemeData get dark => _build(PesoColors.dark, Brightness.dark);

  static ThemeData _build(PesoColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.gold,
      onPrimary: c.onGold,
      secondary: c.goldDark,
      onSecondary: c.onGold,
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      fontFamily: AppFonts.body,
      textTheme: _textTheme(c),
      dividerColor: c.border,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.heading,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: c.textPrimary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surface,
        contentTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          color: c.textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.gold,
          foregroundColor: c.onGold,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme(PesoColors c) {
    TextStyle heading(double size, FontWeight weight) => TextStyle(
      fontFamily: AppFonts.heading,
      fontSize: size,
      fontWeight: weight,
      color: c.textPrimary,
    );

    return TextTheme(
      headlineLarge: heading(40, FontWeight.w700),
      headlineMedium: heading(28, FontWeight.w700),
      headlineSmall: heading(24, FontWeight.w700),
      titleLarge: heading(20, FontWeight.w700),
      titleMedium: heading(16, FontWeight.w600),
      labelLarge: heading(16, FontWeight.w600),
      bodyLarge: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 16,
        height: 1.6,
        color: c.textSecondary,
      ),
      bodyMedium: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 14,
        height: 1.5,
        color: c.textSecondary,
      ),
      bodySmall: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 12,
        color: c.textMuted,
      ),
      // Small spaced-out caps labels like "TOTAL VALUE"
      labelSmall: TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        color: c.textMuted,
      ),
    );
  }
}
