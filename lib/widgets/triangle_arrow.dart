import 'package:flutter/material.dart';

/// Solid filled triangle arrow matching the Figma design specifications.
class TriangleArrow extends StatelessWidget {
  final bool isUp;
  final Color color;
  final double width;
  final double height;

  const TriangleArrow({
    super.key,
    required this.isUp,
    required this.color,
    this.width = 10,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _TrianglePainter(isUp: isUp, color: color),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final bool isUp;
  final Color color;

  const _TrianglePainter({required this.isUp, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (isUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.isUp != isUp || oldDelegate.color != color;
}
