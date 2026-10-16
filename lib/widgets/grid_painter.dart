import 'package:flutter/material.dart';
import '../core/constants.dart';

class GridPainter extends CustomPainter {
  final GridType gridType;
  final bool isDark;

  const GridPainter({
    required this.gridType,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = isDark ? const Color(0xFF444450) : const Color(0xFFD6CFC7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF33333F) : const Color(0xFFE2DDD5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final dashedPaint = Paint()
      ..color = isDark ? const Color(0xFF3A3A46) : const Color(0xFFDDD7CF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)), borderPaint);

    if (gridType == GridType.none) return;

    final w = size.width;
    final h = size.height;

    if (gridType == GridType.crossOnly || gridType == GridType.diagonalCross) {
      // Horizontal centerline
      _drawDashedLine(canvas, Offset(0, h / 2), Offset(w, h / 2), dashedPaint);
      // Vertical centerline
      _drawDashedLine(canvas, Offset(w / 2, 0), Offset(w / 2, h), dashedPaint);

      if (gridType == GridType.diagonalCross) {
        // Diagonal lines
        _drawDashedLine(canvas, const Offset(0, 0), Offset(w, h), dashedPaint);
        _drawDashedLine(canvas, Offset(0, h), Offset(w, 0), dashedPaint);
      }
    } else if (gridType == GridType.nineBoxes) {
      // Nine-box grid (1/3 and 2/3 lines)
      _drawDashedLine(canvas, Offset(0, h / 3), Offset(w, h / 3), gridPaint);
      _drawDashedLine(canvas, Offset(0, 2 * h / 3), Offset(w, 2 * h / 3), gridPaint);
      _drawDashedLine(canvas, Offset(w / 3, 0), Offset(w / 3, h), gridPaint);
      _drawDashedLine(canvas, Offset(2 * w / 3, 0), Offset(2 * w / 3, h), gridPaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, {double dash = 6.0, double gap = 4.0}) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = (p2 - p1).distance;
    final unitX = dx / distance;
    final unitY = dy / distance;

    double current = 0.0;
    while (current < distance) {
      final end = (current + dash).clamp(0.0, distance);
      canvas.drawLine(
        Offset(p1.dx + unitX * current, p1.dy + unitY * current),
        Offset(p1.dx + unitX * end, p1.dy + unitY * end),
        paint,
      );
      current += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.gridType != gridType || oldDelegate.isDark != isDark;
  }
}
