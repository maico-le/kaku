import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/stroke.dart';
import 'grid_painter.dart';

class StrokeAnimationWidget extends StatefulWidget {
  final double size;
  final GridType gridType;
  final List<Stroke> strokes;
  final VoidCallback? onAnimationFinished;

  const StrokeAnimationWidget({
    super.key,
    required this.size,
    required this.gridType,
    required this.strokes,
    this.onAnimationFinished,
  });

  @override
  State<StrokeAnimationWidget> createState() => _StrokeAnimationWidgetState();
}

class _StrokeAnimationWidgetState extends State<StrokeAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentStrokeIndex = 0;
  bool _isSlow = false;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _strokeDuration,
    )..addListener(_onAnimationTick)
     ..addStatusListener(_onStatusChanged);

    _startAnimation();
  }

  Duration get _strokeDuration =>
      Duration(milliseconds: _isSlow ? 1400 : 750);

  void _onAnimationTick() {
    setState(() {});
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (_currentStrokeIndex < widget.strokes.length - 1) {
        setState(() {
          _currentStrokeIndex++;
        });
        _controller.reset();
        _controller.forward();
      } else {
        setState(() {
          _isPlaying = false;
        });
        widget.onAnimationFinished?.call();
      }
    }
  }

  void _startAnimation() {
    _currentStrokeIndex = 0;
    _isPlaying = true;
    _controller.duration = _strokeDuration;
    _controller.reset();
    _controller.forward();
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.stop();
        _isPlaying = false;
      } else {
        if (_currentStrokeIndex >= widget.strokes.length - 1 &&
            _controller.isCompleted) {
          _startAnimation();
        } else {
          _controller.forward();
          _isPlaying = true;
        }
      }
    });
  }

  void _toggleSpeed() {
    setState(() {
      _isSlow = !_isSlow;
      _controller.duration = _strokeDuration;
    });
  }

  @override
  void didUpdateWidget(covariant StrokeAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.strokes != widget.strokes) {
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = widget.size / kKanjiVgCoordSize;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
                CustomPaint(
                  painter: GridPainter(
                    gridType: widget.gridType,
                    isDark: isDark,
                  ),
                ),
                CustomPaint(
                  painter: _DemoStrokePainter(
                    strokes: widget.strokes,
                    currentStrokeIndex: _currentStrokeIndex,
                    progress: _controller.value,
                    scale: scale,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Controls: Replay, Play/Pause, Speed toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.replay_rounded),
              tooltip: 'Phát lại từ đầu',
              onPressed: _startAnimation,
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              tooltip: _isPlaying ? 'Tạm dừng' : 'Tiếp tục',
              onPressed: _togglePlayPause,
            ),
            const SizedBox(width: 12),
            FilterChip(
              label: Text(_isSlow ? 'Tốc độ: 0.5x' : 'Tốc độ: 1.0x'),
              selected: _isSlow,
              onSelected: (_) => _toggleSpeed(),
            ),
            const SizedBox(width: 16),
            Text(
              'Nét ${_currentStrokeIndex + 1} / ${widget.strokes.length}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DemoStrokePainter extends CustomPainter {
  final List<Stroke> strokes;
  final int currentStrokeIndex;
  final double progress;
  final double scale;
  final bool isDark;

  _DemoStrokePainter({
    required this.strokes,
    required this.currentStrokeIndex,
    required this.progress,
    required this.scale,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    canvas.save();
    canvas.scale(scale, scale);

    // 1. Draw already completed strokes
    final completedPaint = Paint()
      ..color = isDark ? Colors.white70 : const Color(0xFF2C3E50)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 5.0 / scale;

    for (int i = 0; i < currentStrokeIndex && i < strokes.length; i++) {
      try {
        final path = parseSvgPathData(strokes[i].d);
        canvas.drawPath(path, completedPaint);
      } catch (_) {}
    }

    // 2. Draw current animated stroke partially based on progress
    if (currentStrokeIndex < strokes.length) {
      final currentStroke = strokes[currentStrokeIndex];
      final pts = currentStroke.pts;

      if (pts.length >= 2) {
        final activePaint = Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 6.0 / scale;

        final targetPointsCount = (pts.length * progress).clamp(2.0, pts.length.toDouble()).toInt();
        final animPath = Path()..moveTo(pts.first.x, pts.first.y);
        for (int i = 1; i < targetPointsCount; i++) {
          animPath.lineTo(pts[i].x, pts[i].y);
        }
        canvas.drawPath(animPath, activePaint);

        // Draw stroke number badge at the start point
        final startPt = pts.first;
        final badgePaint = Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(startPt.x, startPt.y), 4.5, badgePaint);

        final textSpan = TextSpan(
          text: '${currentStrokeIndex + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 6.0,
            fontWeight: FontWeight.bold,
          ),
        );
        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(startPt.x - tp.width / 2, startPt.y - tp.height / 2));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DemoStrokePainter old) {
    return old.currentStrokeIndex != currentStrokeIndex ||
        old.progress != progress ||
        old.scale != scale ||
        old.isDark != isDark;
  }
}
