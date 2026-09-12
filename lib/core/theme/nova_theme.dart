import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovaTheme {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF020A04);
  static const Color panel = Color(0xFF04140A);
  static const Color primary = Color(0xFF00FF41);
  static const Color secondary = Color(0xFF00CC33);
  static const Color accent = Color(0xFF39FF14);
  static const Color warning = Color(0xFFFF3333);
  static const Color textPrimary = Color(0xFF00FF41);
  static const Color textMuted = Color(0xFF1F9A42);
  static const Color grid = Color(0xFF003311);

  static ThemeData hacker() {
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onSurface: textPrimary,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      textTheme: GoogleFonts.jetBrainsMonoTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: primary,
      ),
    );
  }
}
