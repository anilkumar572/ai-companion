import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/nova_theme.dart';

class HackerBackground extends StatefulWidget {
  const HackerBackground({super.key});

  @override
  State<HackerBackground> createState() => _HackerBackgroundState();
}

class _HackerBackgroundState extends State<HackerBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
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
          painter: _HackerPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _HackerPainter extends CustomPainter {
  _HackerPainter({required this.progress});

  final double progress;
  final _random = math.Random(7);
  final _chars = r'01ｱｲｳｴｵ$#@%&<>/\|{}[]';

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = NovaTheme.background,
    );

    final gridPaint = Paint()
      ..color = NovaTheme.grid.withValues(alpha: 0.35)
      ..strokeWidth = 0.5;

    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    const columnWidth = 18.0;
    final columns = (size.width / columnWidth).ceil();

    for (var col = 0; col < columns; col++) {
      final x = col * columnWidth + 4;
      final speed = 0.4 + (col % 5) * 0.12;
      final offset = (progress * size.height * speed) % size.height;
      final length = 8 + col % 10;

      for (var row = 0; row < length; row++) {
        final y = (offset + row * 16) % (size.height + 80) - 40;
        if (y < 0 || y > size.height) continue;

        final char = _chars[_random.nextInt(_chars.length)];
        final alpha = (1 - row / length).clamp(0.15, 1.0);
        final textPainter = TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              color: NovaTheme.primary.withValues(alpha: alpha * 0.35),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(canvas, Offset(x, y));
      }
    }

    final scanY = (progress * size.height * 1.2) % size.height;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          NovaTheme.primary.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, scanY - 40, size.width, 80));
    canvas.drawRect(Rect.fromLTWH(0, scanY - 40, size.width, 80), scanPaint);

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          NovaTheme.background.withValues(alpha: 0.9),
        ],
        stops: const [0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignette);
  }

  @override
  bool shouldRepaint(covariant _HackerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
