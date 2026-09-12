import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NovaTheme {
  static const Color background = Color(0xFF07070F);
  static const Color backgroundElevated = Color(0xFF0E0E18);
  static const Color surface = Color(0xFF141422);
  static const Color panel = Color(0xFF1C1C2E);
  static const Color primary = Color(0xFF8B7CF6);
  static const Color secondary = Color(0xFF5B8DEF);
  static const Color accent = Color(0xFF22D3EE);
  static const Color warning = Color(0xFFF87171);
  static const Color success = Color(0xFF34D399);
  static const Color textPrimary = Color(0xFFF5F5FA);
  static const Color textMuted = Color(0xFF9494AD);
  static const Color grid = Color(0xFF2A2A42);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0A0A14),
      Color(0xFF12122A),
      Color(0xFF0D1020),
      Color(0xFF07070F),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary, accent],
  );

  static ThemeData nova() {
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        surface: surface,
        onSurface: textPrimary,
        error: warning,
      ),
      useMaterial3: true,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: textPrimary,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: textTheme.bodyMedium?.copyWith(color: textMuted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textMuted.withValues(alpha: 0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: grid.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: grid.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static BoxDecoration glassCard({
    Color? borderColor,
    double radius = 20,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: panel.withValues(alpha: 0.72),
      border: Border.all(
        color: (borderColor ?? primary).withValues(alpha: 0.22),
      ),
      boxShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static Widget frosted({
    required Widget child,
    double radius = 20,
    EdgeInsets padding = const EdgeInsets.all(16),
    Color? borderColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: glassCard(borderColor: borderColor, radius: radius),
          child: child,
        ),
      ),
    );
  }
}
