import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovaTheme {
  static const Color background = Color(0xFF05070D);
  static const Color surface = Color(0xFF0D1220);
  static const Color primary = Color(0xFF00D4FF);
  static const Color secondary = Color(0xFF7B61FF);
  static const Color accent = Color(0xFF00FFB2);
  static const Color warning = Color(0xFFFFB347);
  static const Color textPrimary = Color(0xFFE8F4FF);
  static const Color textMuted = Color(0xFF7A8CA8);

  static ThemeData dark() {
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
      textTheme: GoogleFonts.orbitronTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
