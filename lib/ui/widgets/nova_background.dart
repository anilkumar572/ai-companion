import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/nova_theme.dart';

class NovaBackground extends StatefulWidget {
  const NovaBackground({super.key});

  @override
  State<NovaBackground> createState() => _NovaBackgroundState();
}

class _NovaBackgroundState extends State<NovaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _NovaBackgroundPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _NovaBackgroundPainter extends CustomPainter {
  _NovaBackgroundPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawRect(rect, Paint()..shader = NovaTheme.backgroundGradient.createShader(rect));

    _drawAmbientOrb(
      canvas,
      size,
      Offset(size.width * (0.18 + math.sin(progress * math.pi * 2) * 0.04), size.height * 0.12),
      size.width * 0.42,
      NovaTheme.primary.withValues(alpha: 0.22),
    );
    _drawAmbientOrb(
      canvas,
      size,
      Offset(size.width * (0.82 + math.cos(progress * math.pi * 2) * 0.03), size.height * 0.28),
      size.width * 0.36,
      NovaTheme.secondary.withValues(alpha: 0.18),
    );
    _drawAmbientOrb(
      canvas,
      size,
      Offset(size.width * 0.5, size.height * (0.78 + math.sin(progress * math.pi * 2 + 1) * 0.02)),
      size.width * 0.48,
      NovaTheme.accent.withValues(alpha: 0.12),
    );

    _drawParticles(canvas, size);

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: [
          Colors.transparent,
          NovaTheme.background.withValues(alpha: 0.55),
        ],
        stops: const [0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  void _drawAmbientOrb(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    Color color,
  ) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawParticles(Canvas canvas, Size size) {
    const count = 28;
    for (var i = 0; i < count; i++) {
      final t = (i / count) + progress;
      final x = (math.sin(t * math.pi * 2) * 0.5 + 0.5) * size.width;
      final y = ((t * 1.7) % 1.0) * size.height;
      final alpha = 0.08 + (i % 4) * 0.04;
      final radius = 1.2 + (i % 3);

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = NovaTheme.textPrimary.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NovaBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
