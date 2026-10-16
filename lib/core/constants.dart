import 'dart:math';

/// Constants for canvas and stroke matching in Kaku (書く).
const double kKanjiVgCoordSize = 109.0;
const int kResamplePointCount = 32;

enum DifficultyLevel {
  easy,
  medium,
  strict,
}

class MatchThresholds {
  final double maxStartEndDist;
  final double maxMeanDist;
  final double maxFrechetDist;
  final double minLengthRatio;
  final double maxLengthRatio;
  final double maxAngleDiffRad; // radians

  const MatchThresholds({
    required this.maxStartEndDist,
    required this.maxMeanDist,
    required this.maxFrechetDist,
    required this.minLengthRatio,
    required this.maxLengthRatio,
    required this.maxAngleDiffRad,
  });

  static const MatchThresholds easy = MatchThresholds(
    maxStartEndDist: 34.0,
    maxMeanDist: 26.0,
    maxFrechetDist: 36.0,
    minLengthRatio: 0.45,
    maxLengthRatio: 2.2,
    maxAngleDiffRad: 75.0 * (pi / 180.0),
  );

  static const MatchThresholds medium = MatchThresholds(
    maxStartEndDist: 25.0,
    maxMeanDist: 18.0,
    maxFrechetDist: 28.0,
    minLengthRatio: 0.55,
    maxLengthRatio: 1.85,
    maxAngleDiffRad: 55.0 * (pi / 180.0),
  );

  static const MatchThresholds strict = MatchThresholds(
    maxStartEndDist: 18.0,
    maxMeanDist: 13.0,
    maxFrechetDist: 20.0,
    minLengthRatio: 0.70,
    maxLengthRatio: 1.45,
    maxAngleDiffRad: 40.0 * (pi / 180.0),
  );

  static MatchThresholds forDifficulty(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.easy:
        return easy;
      case DifficultyLevel.medium:
        return medium;
      case DifficultyLevel.strict:
        return strict;
    }
  }
}

enum GridType {
  diagonalCross, // Chữ thập + đường chéo
  crossOnly,     // Chỉ chữ thập
  nineBoxes,     // Lưới 9 ô (cửu cung cách)
  none,          // Không lưới
}

enum PracticeMode {
  demo,   // 1. Xem mẫu
  trace,  // 2. Tô theo
  recall, // 3. Tự viết
}

enum StrokeErrorReason {
  none,
  wrongOrder,     // Sai thứ tự
  wrongDirection, // Sai hướng
  wrongShape,     // Sai hình dạng / vị trí
  tooShort,       // Nét quá ngắn (chạm nhầm)
}
