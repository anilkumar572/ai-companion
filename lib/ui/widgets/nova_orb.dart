import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/nova_state.dart';
import '../../core/theme/nova_theme.dart';

class NovaOrb extends StatefulWidget {
  const NovaOrb({
    super.key,
    required this.state,
    required this.audioLevel,
    required this.onTap,
  });

  final NovaAgentState state;
  final double audioLevel;
  final VoidCallback onTap;

  @override
  State<NovaOrb> createState() => _NovaOrbState();
}

class _NovaOrbState extends State<NovaOrb> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _ringController;
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant NovaOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateSpeed();
  }

  void _updateSpeed() {
    final speed = switch (widget.state) {
      NovaAgentState.idle => 1.0,
      NovaAgentState.listening => 1.8,
      NovaAgentState.thinking => 2.4,
      NovaAgentState.speaking => 1.5,
      NovaAgentState.error => 0.8,
    };

    _pulseController.duration = Duration(milliseconds: (2200 / speed).round());
    _ringController.duration = Duration(milliseconds: (8000 / speed).round());
    _scanController.duration = Duration(milliseconds: (1600 / speed).round());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateSpeed();

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 320,
        height: 320,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _pulseController,
            _ringController,
            _scanController,
          ]),
          builder: (context, child) {
            return CustomPaint(
              painter: _NovaOrbPainter(
                state: widget.state,
                pulse: _pulseController.value,
                rotation: _ringController.value,
                scan: _scanController.value,
                audioLevel: widget.audioLevel,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NovaOrbPainter extends CustomPainter {
  _NovaOrbPainter({
    required this.state,
    required this.pulse,
    required this.rotation,
    required this.scan,
    required this.audioLevel,
  });

  final NovaAgentState state;
  final double pulse;
  final double rotation;
  final double scan;
  final double audioLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide * 0.22;
    final colors = _paletteForState(state);
    final reactiveBoost = state == NovaAgentState.listening ? audioLevel * 18 : 0;

    _drawGlow(canvas, center, baseRadius + 42 + pulse * 18 + reactiveBoost, colors.glow);
    _drawRings(canvas, center, baseRadius, colors);
    _drawCore(canvas, center, baseRadius + pulse * 10 + reactiveBoost, colors);
    _drawParticles(canvas, center, baseRadius, colors.accent);
    _drawScanner(canvas, center, baseRadius + 28, colors.accent);
  }

  void _drawGlow(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawRings(Canvas canvas, Offset center, double radius, _OrbPalette colors) {
    for (var i = 0; i < 3; i++) {
      final ringRadius = radius + 34 + (i * 22) + pulse * 8;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 + i * 0.4
        ..color = colors.ring.withValues(alpha: 0.45 - i * 0.1);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation * math.pi * 2 + i * 0.8);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        0.2,
        math.pi * 1.2,
        false,
        paint,
      );
      canvas.restore();
    }
  }

  void _drawCore(Canvas canvas, Offset center, double radius, _OrbPalette colors) {
    final corePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        colors: [
          colors.coreHighlight,
          colors.core,
          colors.coreShadow,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, corePaint);

    final highlight = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.45),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center.translate(-radius * 0.25, -radius * 0.28), radius: radius * 0.45));
    canvas.drawCircle(center.translate(-radius * 0.18, -radius * 0.22), radius * 0.28, highlight);
  }

  void _drawParticles(Canvas canvas, Offset center, double radius, Color color) {
    const particleCount = 18;
    for (var i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * math.pi * 2 + rotation * math.pi * 2;
      final distance = radius + 56 + math.sin((scan + i) * math.pi * 2) * 10;
      final offset = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      final paint = Paint()..color = color.withValues(alpha: 0.35 + (i % 3) * 0.15);
      canvas.drawCircle(offset, 2.2 + (i % 2), paint);
    }
  }

  void _drawScanner(Canvas canvas, Offset center, double radius, Color color) {
    if (state != NovaAgentState.thinking && state != NovaAgentState.listening) {
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = SweepGradient(
        startAngle: scan * math.pi * 2,
        endAngle: scan * math.pi * 2 + math.pi / 3,
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  _OrbPalette _paletteForState(NovaAgentState state) {
    return switch (state) {
      NovaAgentState.idle => const _OrbPalette(
          core: Color(0xFF0A4D68),
          coreHighlight: NovaTheme.primary,
          coreShadow: Color(0xFF031B2E),
          ring: NovaTheme.primary,
          glow: NovaTheme.primary,
          accent: NovaTheme.accent,
        ),
      NovaAgentState.listening => const _OrbPalette(
          core: Color(0xFF0D5E4F),
          coreHighlight: NovaTheme.accent,
          coreShadow: Color(0xFF04261F),
          ring: NovaTheme.accent,
          glow: NovaTheme.accent,
          accent: Colors.white,
        ),
      NovaAgentState.thinking => const _OrbPalette(
          core: Color(0xFF3A2D7A),
          coreHighlight: NovaTheme.secondary,
          coreShadow: Color(0xFF140F33),
          ring: NovaTheme.secondary,
          glow: NovaTheme.secondary,
          accent: NovaTheme.warning,
        ),
      NovaAgentState.speaking => const _OrbPalette(
          core: Color(0xFF0B4F7A),
          coreHighlight: Color(0xFF4CC9FF),
          coreShadow: Color(0xFF032338),
          ring: Color(0xFF4CC9FF),
          glow: Color(0xFF4CC9FF),
          accent: NovaTheme.primary,
        ),
      NovaAgentState.error => const _OrbPalette(
          core: Color(0xFF5A1F1F),
          coreHighlight: Color(0xFFFF6B6B),
          coreShadow: Color(0xFF2A0B0B),
          ring: Color(0xFFFF6B6B),
          glow: Color(0xFFFF6B6B),
          accent: Color(0xFFFFB4B4),
        ),
    };
  }

  @override
  bool shouldRepaint(covariant _NovaOrbPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.pulse != pulse ||
        oldDelegate.rotation != rotation ||
        oldDelegate.scan != scan ||
        oldDelegate.audioLevel != audioLevel;
  }
}

class _OrbPalette {
  const _OrbPalette({
    required this.core,
    required this.coreHighlight,
    required this.coreShadow,
    required this.ring,
    required this.glow,
    required this.accent,
  });

  final Color core;
  final Color coreHighlight;
  final Color coreShadow;
  final Color ring;
  final Color glow;
  final Color accent;
}
