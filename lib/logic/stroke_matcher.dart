import 'dart:math';
import 'dart:ui';
import '../core/constants.dart';
import '../models/stroke.dart';
import 'resampler.dart';

class MatchEvaluation {
  final bool isPass;
  final double startDist;
  final double endDist;
  final double meanDist;
  final double frechetDist;
  final double lengthRatio;
  final double angleDiff;

  const MatchEvaluation({
    required this.isPass,
    required this.startDist,
    required this.endDist,
    required this.meanDist,
    required this.frechetDist,
    required this.lengthRatio,
    required this.angleDiff,
  });
}

class MatchResult {
  final bool isPass;
  final StrokeErrorReason errorReason;
  final int? matchedFutureIndex; // 1-based stroke number in character
  final MatchEvaluation evaluation;

  const MatchResult({
    required this.isPass,
    required this.errorReason,
    this.matchedFutureIndex,
    required this.evaluation,
  });

  static MatchResult tooShort() {
    return const MatchResult(
      isPass: false,
      errorReason: StrokeErrorReason.tooShort,
      evaluation: MatchEvaluation(
        isPass: false,
        startDist: 0,
        endDist: 0,
        meanDist: 0,
        frechetDist: 0,
        lengthRatio: 0,
        angleDiff: 0,
      ),
    );
  }
}

class StrokeMatcher {
  /// Maps raw canvas touch points to KanjiVG 109x109 coordinate system.
  static List<StrokePoint> normalizePoints(
    List<Offset> rawPoints,
    double canvasSize,
  ) {
    if (canvasSize <= 0) return [];
    final scale = kKanjiVgCoordSize / canvasSize;
    return rawPoints
        .map<StrokePoint>((Offset p) => StrokePoint(p.dx * scale, p.dy * scale))
        .toList();
  }

  /// Calculates the discrete Fréchet distance between two point sequences of length N.
  static double computeDiscreteFrechet(
    List<StrokePoint> p,
    List<StrokePoint> q,
  ) {
    final n = p.length;
    final m = q.length;
    if (n == 0 || m == 0) return double.infinity;

    // Allocate DP matrix
    final dp = List.generate(n, (_) => List<double>.filled(m, -1.0));

    double ca(int i, int j) {
      if (dp[i][j] > -0.5) return dp[i][j];

      final d = p[i].distanceTo(q[j]);
      if (i == 0 && j == 0) {
        dp[i][j] = d;
      } else if (i > 0 && j == 0) {
        dp[i][j] = max(ca(i - 1, 0), d);
      } else if (i == 0 && j > 0) {
        dp[i][j] = max(ca(0, j - 1), d);
      } else {
        dp[i][j] = max(
          min(ca(i - 1, j), min(ca(i - 1, j - 1), ca(i, j - 1))),
          d,
        );
      }
      return dp[i][j];
    }

    return ca(n - 1, m - 1);
  }

  /// Pure function: Evaluates whether [userSampled] matches [stdSampled].
  static MatchEvaluation evaluateStroke({
    required List<StrokePoint> userSampled,
    required List<StrokePoint> stdSampled,
    required MatchThresholds thresholds,
    required double stdArcLength,
    required double userArcLength,
  }) {
    if (userSampled.length != stdSampled.length || userSampled.isEmpty) {
      return const MatchEvaluation(
        isPass: false,
        startDist: 999,
        endDist: 999,
        meanDist: 999,
        frechetDist: 999,
        lengthRatio: 0,
        angleDiff: pi,
      );
    }

    final n = userSampled.length;
    final startDist = userSampled.first.distanceTo(stdSampled.first);
    final endDist = userSampled.last.distanceTo(stdSampled.last);

    double sumDist = 0.0;
    for (int i = 0; i < n; i++) {
      sumDist += userSampled[i].distanceTo(stdSampled[i]);
    }
    final meanDist = sumDist / n;

    final frechetDist = computeDiscreteFrechet(userSampled, stdSampled);

    final lengthRatio = stdArcLength > 1e-4
        ? (userArcLength / stdArcLength)
        : 1.0;

    final userAngle = StrokeResampler.calculateOrientationAngle(
      userSampled.first,
      userSampled.last,
    );
    final stdAngle = StrokeResampler.calculateOrientationAngle(
      stdSampled.first,
      stdSampled.last,
    );
    final angleDiff = StrokeResampler.angleDifference(userAngle, stdAngle);

    // Special handling for very short strokes (e.g. dots, tenten, tick strokes)
    final isVeryShortStroke = stdArcLength < 18.0;

    bool pass;
    if (isVeryShortStroke) {
      // For very short strokes / dots, angle is highly sensitive to touch jitter,
      // so we rely primarily on proximity (mean distance and start/end distance)
      final relaxedMaxDist = max(thresholds.maxMeanDist * 1.35, 16.0);
      final distPass = meanDist <= relaxedMaxDist &&
          startDist <= relaxedMaxDist * 1.4 &&
          endDist <= relaxedMaxDist * 1.4;
      final lengthPass = userArcLength >= 2.0 && lengthRatio <= 3.2;
      pass = distPass && lengthPass;
    } else {
      // Normal stroke evaluation
      final startEndPass = startDist <= thresholds.maxStartEndDist &&
          endDist <= thresholds.maxStartEndDist;
      final meanPass = meanDist <= thresholds.maxMeanDist;
      final frechetPass = frechetDist <= thresholds.maxFrechetDist;
      final lengthPass = lengthRatio >= thresholds.minLengthRatio &&
          lengthRatio <= thresholds.maxLengthRatio;
      final anglePass = angleDiff <= thresholds.maxAngleDiffRad;

      pass = startEndPass && meanPass && frechetPass && lengthPass && anglePass;
    }

    return MatchEvaluation(
      isPass: pass,
      startDist: startDist,
      endDist: endDist,
      meanDist: meanDist,
      frechetDist: frechetDist,
      lengthRatio: lengthRatio,
      angleDiff: angleDiff,
    );
  }

  /// Complete matching and error classification for a user drawn stroke.
  static MatchResult matchAndClassify({
    required List<StrokePoint> rawUserPoints,
    required List<Stroke> allStrokes,
    required int currentStrokeIndex,
    DifficultyLevel difficulty = DifficultyLevel.medium,
  }) {
    if (currentStrokeIndex < 0 || currentStrokeIndex >= allStrokes.length) {
      return MatchResult.tooShort();
    }

    // 1. Filter jitter and nearby points
    final filteredUser = StrokeResampler.filterClosePoints(rawUserPoints);
    final userLength = StrokeResampler.calculateArcLength(filteredUser);

    final expectedStroke = allStrokes[currentStrokeIndex];
    final stdPoints = expectedStroke.pts;
    final stdLength = StrokeResampler.calculateArcLength(stdPoints);

    // 2. Reject strokes that are way too short (accidental taps),
    // unless the standard stroke itself is a tiny dot (< 10.0)
    final minLengthAllowed = stdLength < 12.0 ? 3.0 : 8.0;
    if (userLength < minLengthAllowed || filteredUser.length < 2) {
      return MatchResult.tooShort();
    }

    // 3. Resample both user stroke and expected stroke to N = 32
    final userSampled = StrokeResampler.resample(
      filteredUser,
      targetCount: kResamplePointCount,
    );
    final expectedSampled = StrokeResampler.resample(
      stdPoints,
      targetCount: kResamplePointCount,
    );

    final thresholds = MatchThresholds.forDifficulty(difficulty);

    // 4. Evaluate against the expected current stroke
    final directEval = evaluateStroke(
      userSampled: userSampled,
      stdSampled: expectedSampled,
      thresholds: thresholds,
      stdArcLength: stdLength,
      userArcLength: userLength,
    );

    if (directEval.isPass) {
      return MatchResult(
        isPass: true,
        errorReason: StrokeErrorReason.none,
        evaluation: directEval,
      );
    }

    // If not matching, classify the error reason:
    // 5. Test if reversed direction (wrong direction)
    final reversedStd = expectedSampled.reversed.toList();
    final reversedEval = evaluateStroke(
      userSampled: userSampled,
      stdSampled: reversedStd,
      thresholds: thresholds,
      stdArcLength: stdLength,
      userArcLength: userLength,
    );

    if (reversedEval.isPass) {
      return MatchResult(
        isPass: false,
        errorReason: StrokeErrorReason.wrongDirection,
        evaluation: directEval,
      );
    }

    // 6. Test if matches any FUTURE stroke (wrong order)
    for (int k = currentStrokeIndex + 1; k < allStrokes.length; k++) {
      final otherPts = allStrokes[k].pts;
      final otherLength = StrokeResampler.calculateArcLength(otherPts);
      final otherSampled = StrokeResampler.resample(
        otherPts,
        targetCount: kResamplePointCount,
      );

      final otherEval = evaluateStroke(
        userSampled: userSampled,
        stdSampled: otherSampled,
        thresholds: thresholds,
        stdArcLength: otherLength,
        userArcLength: userLength,
      );

      if (otherEval.isPass) {
        return MatchResult(
          isPass: false,
          errorReason: StrokeErrorReason.wrongOrder,
          matchedFutureIndex: k + 1, // 1-based index for friendly message
          evaluation: directEval,
        );
      }
    }

    // 7. Otherwise, wrong shape or wrong position
    return MatchResult(
      isPass: false,
      errorReason: StrokeErrorReason.wrongShape,
      evaluation: directEval,
    );
  }
}
