import 'package:flutter/material.dart';

class SparklineChartWidget extends StatelessWidget {
  final List<double> data;
  final bool isGain;
  final double height;

  const SparklineChartWidget({
    super.key,
    required this.data,
    required this.isGain,
    this.height = 42,
  });

  @override
  Widget build(BuildContext context) {
    final strokeColor =
        isGain ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final fillColor =
        isGain ? const Color(0x2216A34A) : const Color(0x22DC2626);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          strokeColor: strokeColor,
          fillColor: fillColor,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color strokeColor;
  final Color fillColor;

  _SparklinePainter({
    required this.data,
    required this.strokeColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).abs();
    final effectiveRange = range == 0 ? 1.0 : range;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor, fillColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final usableWidth = size.width - 8.0;
    final stepX = usableWidth / (data.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = 4.0 + (i * stepX);
      // Invert Y so highest value is at top (y=0)
      final norm = (data[i] - minVal) / effectiveRange;
      final y = size.height - (norm * (size.height - 8)) - 4;
      points.add(Offset(x, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);

    final dotPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}
