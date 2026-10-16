import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../logic/stroke_matcher.dart';
import '../models/character_data.dart';
import '../providers/app_providers.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/stroke_animation.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  final CharacterData character;
  final List<CharacterData>? playlist; // For "Next Character" navigation
  final int initialPlaylistIndex;

  const PracticeScreen({
    super.key,
    required this.character,
    this.playlist,
    this.initialPlaylistIndex = 0,
  });

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  late CharacterData _currentCharacter;
  late int _playlistIndex;

  PracticeMode _mode = PracticeMode.recall;
  int _completedStrokeCount = 0;
  int _consecutiveWrongAttempts = 0;
  int _totalWrongAttempts = 0;
  bool _usedHint = false;
  bool _showHint = false;

  String? _feedbackMessage;
  Color _feedbackColor = Colors.transparent;
  Timer? _feedbackTimer;

  List<Offset>? _errorStrokePoints;
  Timer? _errorStrokeTimer;

  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _currentCharacter = widget.character;
    _playlistIndex = widget.initialPlaylistIndex;
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _errorStrokeTimer?.cancel();
    super.dispose();
  }

  void _resetPractice({PracticeMode? newMode}) {
    _feedbackTimer?.cancel();
    _errorStrokeTimer?.cancel();
    setState(() {
      if (newMode != null) _mode = newMode;
      _completedStrokeCount = 0;
      _consecutiveWrongAttempts = 0;
      _totalWrongAttempts = 0;
      _usedHint = false;
      _showHint = false;
      _feedbackMessage = null;
      _errorStrokePoints = null;
      _isCompleted = false;
    });
  }

  void _goToNextCharacter() {
    if (widget.playlist != null && _playlistIndex < widget.playlist!.length - 1) {
      setState(() {
        _playlistIndex++;
        _currentCharacter = widget.playlist![_playlistIndex];
        _resetPractice();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onStrokeDrawn(List<Offset> rawPoints, double canvasSize) {
    if (_isCompleted || _completedStrokeCount >= _currentCharacter.strokes.length) {
      return;
    }

    final settings = ref.read(settingsProvider);

    // Normalize touch points to 109x109 KanjiVG scale
    final normalized = StrokeMatcher.normalizePoints(rawPoints, canvasSize);

    // Match against current and future strokes
    final matchResult = StrokeMatcher.matchAndClassify(
      rawUserPoints: normalized,
      allStrokes: _currentCharacter.strokes,
      currentStrokeIndex: _completedStrokeCount,
      difficulty: settings.difficulty,
    );

    if (matchResult.isPass) {
      // Stroke Correct!
      if (settings.hapticEnabled) {
        HapticFeedback.lightImpact();
      }
      if (settings.soundEnabled) {
        SystemSound.play(SystemSoundType.click);
      }

      setState(() {
        _completedStrokeCount++;
        _consecutiveWrongAttempts = 0;
        _showHint = false;
        _errorStrokePoints = null;
        _feedbackMessage = 'Đúng nét $_completedStrokeCount / ${_currentCharacter.strokes.length}';
        _feedbackColor = AppColors.strokeCorrect;
      });

      _setFeedbackDismissTimer();

      // Check if character is completed
      if (_completedStrokeCount == _currentCharacter.strokes.length) {
        _onCharacterCompleted();
      }
    } else {
      // Stroke Wrong!
      _totalWrongAttempts++;
      _consecutiveWrongAttempts++;

      if (settings.hapticEnabled) {
        HapticFeedback.mediumImpact();
      }

      String message;
      switch (matchResult.errorReason) {
        case StrokeErrorReason.wrongOrder:
          final futureNum = matchResult.matchedFutureIndex ?? (_completedStrokeCount + 2);
          message = 'Sai thứ tự: nét này là nét số $futureNum, phải viết sau!';
          break;
        case StrokeErrorReason.wrongDirection:
          message = 'Sai hướng: chú ý hướng vẽ điểm đầu → kết thúc';
          break;
        case StrokeErrorReason.tooShort:
          message = 'Nét quá ngắn';
          break;
        case StrokeErrorReason.wrongShape:
        case StrokeErrorReason.none:
          message = 'Nét chưa đúng hình dạng hoặc vị trí';
          break;
      }

      // Check 3 consecutive mistakes -> auto-hint
      if (_consecutiveWrongAttempts >= 3) {
        _showHint = true;
        _usedHint = true;
        message += ' • Đã mở gợi ý nét!';
      }

      setState(() {
        _feedbackMessage = message;
        _feedbackColor = AppColors.strokeWrong;
        _errorStrokePoints = rawPoints;
      });

      // Clear red error stroke after 400ms
      _errorStrokeTimer?.cancel();
      _errorStrokeTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _errorStrokePoints = null;
          });
        }
      });

      _setFeedbackDismissTimer(duration: const Duration(milliseconds: 2500));
    }
  }

  void _setFeedbackDismissTimer({Duration duration = const Duration(milliseconds: 1400)}) {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _feedbackMessage = null;
        });
      }
    });
  }

  void _onCharacterCompleted() {
    setState(() {
      _isCompleted = true;
    });

    final isClean = (_mode == PracticeMode.recall) &&
        (_totalWrongAttempts == 0) &&
        (!_usedHint);

    // Save progress
    ref.read(progressNotifierProvider.notifier).recordCompletion(
      codepoint: _currentCharacter.codepoint,
      isCleanRecall: isClean,
      correctStrokes: _currentCharacter.strokes.length,
      wrongAttempts: _totalWrongAttempts,
    );

    // Show completion bottom modal
    _showCompletionDialog(isClean);
  }

  void _showCompletionDialog(bool isClean) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final hasNext = widget.playlist != null &&
            _playlistIndex < widget.playlist!.length - 1;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isClean ? AppColors.strokeCorrectBg : AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isClean ? Icons.workspace_premium_rounded : Icons.check_circle_rounded,
                  color: isClean ? AppColors.strokeCorrect : AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isClean ? 'Xuất sắc! Thuộc hoàn hảo' : 'Đã hoàn thành chữ!',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Số lần viết sai: $_totalWrongAttempts | Dùng gợi ý: ${_usedHint ? 'Có' : 'Không'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Viết lại'),
                      onPressed: () {
                        Navigator.pop(context);
                        _resetPractice();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(hasNext ? Icons.arrow_forward_rounded : Icons.check_rounded),
                      label: Text(hasNext ? 'Chữ tiếp theo' : 'Xong'),
                      onPressed: () {
                        Navigator.pop(context);
                        _goToNextCharacter();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _undoStroke() {
    if (_completedStrokeCount > 0 && !_isCompleted) {
      setState(() {
        _completedStrokeCount--;
        _consecutiveWrongAttempts = 0;
        _showHint = false;
        _feedbackMessage = 'Đã hoàn tác';
        _feedbackColor = Colors.grey;
      });
      _setFeedbackDismissTimer();
    }
  }

  void _triggerHint() {
    setState(() {
      _showHint = true;
      _usedHint = true;
      _feedbackMessage = 'Đã hiện gợi ý nét số ${_completedStrokeCount + 1}';
      _feedbackColor = AppColors.strokeHint;
    });
    _setFeedbackDismissTimer();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Responsive square canvas: fills width with padding, or fits comfortably in viewport
    final canvasSize = min(screenSize.width - 32, screenSize.height * 0.46).clamp(240.0, 420.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentCharacter.char,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Thông tin chữ',
            onPressed: () => _showCharacterInfoModal(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header: Reading, Meaning & Stroke count
              _buildCharacterHeader(),
              const SizedBox(height: 12),

              // Segmented Button: 3 Modes (Demo / Trace / Recall)
              SegmentedButton<PracticeMode>(
                segments: const [
                  ButtonSegment(
                    value: PracticeMode.demo,
                    label: Text('Xem mẫu'),
                    icon: Icon(Icons.play_circle_outline_rounded),
                  ),
                  ButtonSegment(
                    value: PracticeMode.trace,
                    label: Text('Tô theo'),
                    icon: Icon(Icons.edit_note_rounded),
                  ),
                  ButtonSegment(
                    value: PracticeMode.recall,
                    label: Text('Tự viết'),
                    icon: Icon(Icons.draw_rounded),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (Set<PracticeMode> newSelection) {
                  _resetPractice(newMode: newSelection.first);
                },
              ),
              const SizedBox(height: 14),

              // Feedback Banner
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 32,
                alignment: Alignment.center,
                child: _feedbackMessage != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: _feedbackColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _feedbackColor, width: 1.2),
                        ),
                        child: Text(
                          _feedbackMessage!,
                          style: TextStyle(
                            color: _feedbackColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),

              // Canvas Area
              if (_mode == PracticeMode.demo)
                StrokeAnimationWidget(
                  size: canvasSize,
                  gridType: settings.gridType,
                  strokes: _currentCharacter.strokes,
                )
              else
                DrawingCanvas(
                  size: canvasSize,
                  gridType: settings.gridType,
                  mode: _mode,
                  allStrokes: _currentCharacter.strokes,
                  completedStrokeCount: _completedStrokeCount,
                  errorStrokePoints: _errorStrokePoints,
                  strokeWidth: settings.strokeWidth,
                  userStrokeColor: settings.strokeColor,
                  showHint: _showHint,
                  onStrokeCompleted: (pts) => _onStrokeDrawn(pts, canvasSize),
                ),

              const SizedBox(height: 14),

              // Control Actions (One-handed bottom toolbar)
              if (_mode != PracticeMode.demo) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Undo
                    OutlinedButton.icon(
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Hoàn tác'),
                      onPressed: _completedStrokeCount > 0 && !_isCompleted
                          ? _undoStroke
                          : null,
                    ),
                    // Clear
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Xóa hết'),
                      onPressed: _completedStrokeCount > 0 && !_isCompleted
                          ? () => _resetPractice()
                          : null,
                    ),
                    // Hint
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.lightbulb_outline_rounded),
                      label: const Text('Gợi ý'),
                      onPressed: !_isCompleted &&
                              _completedStrokeCount < _currentCharacter.strokes.length
                          ? _triggerHint
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Tiến độ: $_completedStrokeCount / ${_currentCharacter.strokes.length} nét',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterHeader() {
    final subText = _currentCharacter.romaji ??
        _currentCharacter.meaning ??
        '';

    return Column(
      children: [
        if (subText.isNotEmpty)
          Text(
            subText,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        if (_currentCharacter.system == WritingSystem.kanji) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_currentCharacter.onReadings.isNotEmpty)
                Text(
                  'On: ${_currentCharacter.onReadings.take(2).join(', ')}  ',
                  style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
              if (_currentCharacter.kunReadings.isNotEmpty)
                Text(
                  'Kun: ${_currentCharacter.kunReadings.take(2).join(', ')}',
                  style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _showCharacterInfoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _currentCharacter.char,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhóm / Cấp: ${_currentCharacter.group}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Số nét chuẩn: ${_currentCharacter.strokeCount}'),
                      Text('Mã Unicode: ${_currentCharacter.codepoint}'),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              if (_currentCharacter.meaning != null && _currentCharacter.meaning!.isNotEmpty) ...[
                Text('Nghĩa: ${_currentCharacter.meaning!}', style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 6),
              ],
              if (_currentCharacter.onReadings.isNotEmpty) ...[
                Text('Âm On: ${_currentCharacter.onReadings.join(', ')}', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
              ],
              if (_currentCharacter.kunReadings.isNotEmpty) ...[
                Text('Âm Kun: ${_currentCharacter.kunReadings.join(', ')}', style: const TextStyle(fontSize: 14)),
              ],
            ],
          ),
        );
      },
    );
  }
}
