import 'package:flutter/material.dart';

import '../../core/theme/nova_theme.dart';

class ScanlinesOverlay extends StatelessWidget {
  const ScanlinesOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ScanlinePainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.12);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }

    final border = Paint()
      ..color = NovaTheme.primary.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Rect.fromLTWH(8, 8, size.width - 16, size.height - 16), border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
