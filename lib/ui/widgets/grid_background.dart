import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/nova_theme.dart';

class GridBackground extends StatelessWidget {
  const GridBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
      size: Size.infinite,
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NovaTheme.primary.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const spacing = 42.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          NovaTheme.background.withValues(alpha: 0.85),
        ],
        stops: const [0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignette);

    final sweep = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          NovaTheme.secondary.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        transform: GradientRotation(math.pi / 4),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sweep);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
