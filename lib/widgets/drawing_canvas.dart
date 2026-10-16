import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/stroke.dart';
import 'grid_painter.dart';

class DrawingCanvas extends StatefulWidget {
  final double size;
  final GridType gridType;
  final PracticeMode mode;
  final List<Stroke> allStrokes;
  final int completedStrokeCount;
  final List<Offset>? errorStrokePoints; // Points of stroke that just failed (shown in red temporarily)
  final double strokeWidth;
  final Color userStrokeColor;
  final bool showHint; // Explicit hint requested
  final ValueChanged<List<Offset>> onStrokeCompleted;

  const DrawingCanvas({
    super.key,
    required this.size,
    required this.gridType,
    required this.mode,
    required this.allStrokes,
    required this.completedStrokeCount,
    this.errorStrokePoints,
    this.strokeWidth = 5.0,
    this.userStrokeColor = const Color(0xFF1E293B),
    this.showHint = false,
    required this.onStrokeCompleted,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> with SingleTickerProviderStateMixin {
  int? _activePointerId;
  final ValueNotifier<List<Offset>> _activeStrokeNotifier = ValueNotifier([]);
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 4.0, end: 9.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _activeStrokeNotifier.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointerId == null) {
      _activePointerId = event.pointer;
      _activeStrokeNotifier.value = [event.localPosition];
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer == _activePointerId) {
      final currentList = _activeStrokeNotifier.value;
      // Filter jitter points during live draw
      if (currentList.isNotEmpty) {
        final last = currentList.last;
        final d = (event.localPosition - last).distance;
        if (d < 1.0) return;
      }
      _activeStrokeNotifier.value = [...currentList, event.localPosition];
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _activePointerId) {
      final finishedStroke = List<Offset>.from(_activeStrokeNotifier.value);
      _activePointerId = null;
      _activeStrokeNotifier.value = [];

      if (finishedStroke.length >= 2) {
        widget.onStrokeCompleted(finishedStroke);
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activePointerId) {
      _activePointerId = null;
      _activeStrokeNotifier.value = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = widget.size / kKanjiVgCoordSize;

    return Center(
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: isDark ? AppColors.canvasPaperDark : AppColors.canvasPaperLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Grid Painter
              CustomPaint(
                painter: GridPainter(
                  gridType: widget.gridType,
                  isDark: isDark,
                ),
              ),

              // 2. Background Stored Strokes & Trace Guidelines
              CustomPaint(
                painter: _StaticStrokesPainter(
                  allStrokes: widget.allStrokes,
                  completedCount: widget.completedStrokeCount,
                  mode: widget.mode,
                  showHint: widget.showHint,
                  scale: scale,
                  strokeWidth: widget.strokeWidth,
                  errorStroke: widget.errorStrokePoints,
                  isDark: isDark,
                ),
              ),

              // 3. Pulsing Start Point Indicator for next stroke (in Trace mode or when Hint active)
              if ((widget.mode == PracticeMode.trace || widget.showHint) &&
                  widget.completedStrokeCount < widget.allStrokes.length)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final nextStroke = widget.allStrokes[widget.completedStrokeCount];
                    if (nextStroke.pts.isEmpty) return const SizedBox.shrink();
                    final firstPt = nextStroke.pts.first;
                    final targetOffset = Offset(firstPt.x * scale, firstPt.y * scale);

                    return CustomPaint(
                      painter: _PulsingIndicatorPainter(
                        center: targetOffset,
                        radius: _pulseAnimation.value,
                        color: AppColors.strokeHint,
                      ),
                    );
                  },
                ),

              // 4. Active In-Progress Stroke (Repaints independently with 60fps)
              CustomPaint(
                painter: _ActiveStrokePainter(
                  notifier: _activeStrokeNotifier,
                  strokeWidth: widget.strokeWidth,
                  color: isDark ? Colors.white : widget.userStrokeColor,
                ),
              ),

              // 5. Multi-touch gesture listener (Filters to single pointer)
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaticStrokesPainter extends CustomPainter {
  final List<Stroke> allStrokes;
  final int completedCount;
  final PracticeMode mode;
  final bool showHint;
  final double scale;
  final double strokeWidth;
  final List<Offset>? errorStroke;
  final bool isDark;

  _StaticStrokesPainter({
    required this.allStrokes,
    required this.completedCount,
    required this.mode,
    required this.showHint,
    required this.scale,
    required this.strokeWidth,
    required this.errorStroke,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Trace mode: draw faint background outlines for upcoming strokes
    if (mode == PracticeMode.trace) {
      final tracePaint = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : AppColors.strokeTrace.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth / scale;

      for (int i = completedCount; i < allStrokes.length; i++) {
        try {
          final path = parseSvgPathData(allStrokes[i].d);
          canvas.drawPath(path, tracePaint);
        } catch (_) {}
      }
    }

    // 2. Draw Hint stroke (if requested or triggered)
    if (showHint && completedCount < allStrokes.length) {
      final hintPaint = Paint()
        ..color = AppColors.strokeHint.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = (strokeWidth + 1.0) / scale;

      try {
        final path = parseSvgPathData(allStrokes[completedCount].d);
        canvas.drawPath(path, hintPaint);
      } catch (_) {}
    }

    // 3. Completed strokes (drawn in standard clean KanjiVG SVG path)
    final correctPaint = Paint()
      ..color = AppColors.strokeCorrect
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth / scale;

    for (int i = 0; i < completedCount && i < allStrokes.length; i++) {
      try {
        final path = parseSvgPathData(allStrokes[i].d);
        canvas.drawPath(path, correctPaint);
      } catch (_) {}
    }

    canvas.restore();

    // 4. Draw error stroke if present (in canvas screen coordinates)
    if (errorStroke != null && errorStroke!.length >= 2) {
      final errPaint = Paint()
        ..color = AppColors.strokeWrong
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth;

      final errPath = Path()..moveTo(errorStroke!.first.dx, errorStroke!.first.dy);
      for (int i = 1; i < errorStroke!.length; i++) {
        errPath.lineTo(errorStroke![i].dx, errorStroke![i].dy);
      }
      canvas.drawPath(errPath, errPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StaticStrokesPainter old) {
    return old.completedCount != completedCount ||
        old.mode != mode ||
        old.showHint != showHint ||
        old.scale != scale ||
        old.errorStroke != errorStroke ||
        old.isDark != isDark;
  }
}

class _ActiveStrokePainter extends CustomPainter {
  final ValueNotifier<List<Offset>> notifier;
  final double strokeWidth;
  final Color color;

  _ActiveStrokePainter({
    required this.notifier,
    required this.strokeWidth,
    required this.color,
  }) : super(repaint: notifier);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = notifier.value;
    if (pts.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ActiveStrokePainter oldDelegate) => false;
}

class _PulsingIndicatorPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;

  _PulsingIndicatorPainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Outer halo
    final haloPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 4.0, haloPaint);

    // Inner solid core
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.5, corePaint);
  }

  @override
  bool shouldRepaint(covariant _PulsingIndicatorPainter old) =>
      old.center != center || old.radius != radius || old.color != color;
}
