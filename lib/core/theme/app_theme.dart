import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const _useSystemFonts = bool.fromEnvironment('USE_SYSTEM_FONTS');

  static TextTheme _brandTextTheme(TextTheme base, {Color? bodyColor}) {
    if (_useSystemFonts) {
      return bodyColor == null
          ? base
          : base.apply(bodyColor: bodyColor, displayColor: bodyColor);
    }
    final themed = GoogleFonts.poppinsTextTheme(base);
    return bodyColor == null
        ? themed
        : themed.apply(bodyColor: bodyColor, displayColor: bodyColor);
  }

  // ── RUN Brand Colours ──────────────────────────────────────────────────────
  static const Color runBlue = Color(0xFF003366);
  static const Color runGold = Color(0xFFFFCC00);
  static const Color executiveNavy = Color(0xFF050A30);
  static const Color executiveCard = Color(0xFF1E272E);
  static const Color offWhite = Color(0xFFE1E1E1);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: runBlue,
        secondary: runGold,
        brightness: Brightness.light,
      ),
    );

    final textTheme = _brandTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: Colors.grey.shade50,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: runBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: runGold,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: runBlue,
        foregroundColor: runGold,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: runBlue, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: runBlue,
      onPrimary: Colors.white,
      secondary: runGold,
      onSecondary: executiveNavy,
      surface: executiveCard,
      onSurface: Colors.white,
      error: Color(0xFFCF6679),
      onError: Colors.black,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      primaryColor: runBlue,
      scaffoldBackgroundColor: executiveNavy,
      canvasColor: executiveNavy,
    );

    final textTheme = _brandTextTheme(base.textTheme, bodyColor: Colors.white);

    return base.copyWith(
      textTheme: textTheme.copyWith(
        bodyLarge: textTheme.bodyLarge?.copyWith(color: Colors.white),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: runBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: runGold,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: executiveCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Gold cursor/selection so the caret is visible against dark navy
      // backgrounds (default M3 primary-blue cursor blends in).
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: runGold,
        selectionColor: Color(0x55FFCC00),
        selectionHandleColor: runGold,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: executiveCard,
        selectedItemColor: runGold,
        unselectedItemColor: offWhite,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: executiveCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: offWhite.withValues(alpha: 0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: offWhite.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: runGold, width: 1.2),
        ),
        hintStyle: const TextStyle(color: Colors.white),
      ),
      dividerColor: offWhite.withValues(alpha: 0.12),
    );
  }
}
