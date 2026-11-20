import 'package:flutter/material.dart';

/// A custom painted chevron icon guaranteed to point strictly to the RIGHT (اليمين) `>`.
/// Completely immune to RTL text mirroring, font differences, or platform quirks.
class ChevronRightIcon extends StatelessWidget {
  final Color color;
  final double size;
  final double strokeWidth;

  const ChevronRightIcon({
    super.key,
    required this.color,
    this.size = 20,
    this.strokeWidth = 2.2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.55, size * 0.85),
          painter: _ChevronRightPainter(
            color: color,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _ChevronRightPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _ChevronRightPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final strokeOffset = strokeWidth / 2;
    final path = Path();
    // Points strictly to the RIGHT (اليمين) >
    // Starts at top-left (x = offset, y = offset)
    // Goes to middle-right (x = width - offset, y = height / 2)
    // Goes to bottom-left (x = offset, y = height - offset)
    path.moveTo(strokeOffset, strokeOffset);
    path.lineTo(size.width - strokeOffset, size.height / 2);
    path.lineTo(strokeOffset, size.height - strokeOffset);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChevronRightPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
