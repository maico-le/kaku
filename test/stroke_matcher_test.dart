import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaku/core/constants.dart';
import 'package:kaku/logic/resampler.dart';
import 'package:kaku/logic/stroke_matcher.dart';
import 'package:kaku/models/stroke.dart';

void main() {
  group('StrokeResampler Tests', () {
    test('resample returns exactly targetCount points', () {
      final input = [
        const StrokePoint(10, 10),
        const StrokePoint(20, 10),
        const StrokePoint(50, 10),
      ];
      final resampled = StrokeResampler.resample(input, targetCount: 32);
      expect(resampled.length, 32);
      expect(resampled.first.x, 10.0);
      expect(resampled.first.y, 10.0);
      expect(resampled.last.x, 50.0);
      expect(resampled.last.y, 10.0);
    });

    test('calculateArcLength computes polyline distance accurately', () {
      final input = [
        const StrokePoint(0, 0),
        const StrokePoint(30, 0),
        const StrokePoint(30, 40),
      ];
      final length = StrokeResampler.calculateArcLength(input);
      expect(length, closeTo(70.0, 0.001));
    });

    test('filterClosePoints eliminates jitter points', () {
      final input = [
        const StrokePoint(10, 10),
        const StrokePoint(10.2, 10.1),
        const StrokePoint(10.4, 10.3),
        const StrokePoint(20, 20),
      ];
      final filtered = StrokeResampler.filterClosePoints(input, minDist: 2.0);
      expect(filtered.length, 2);
      expect(filtered.first.x, 10.0);
      expect(filtered.last.x, 20.0);
    });
  });

  group('StrokeMatcher Tests', () {
    // Standard horizontal stroke (e.g. stroke 1 of Kanji 一 or 日 top)
    final stroke1 = Stroke(
      d: 'M20,30 L80,30',
      pts: List.generate(
        40,
        (i) => StrokePoint(20.0 + (60.0 * i / 39.0), 30.0),
      ),
    );

    // Standard vertical stroke (e.g. stroke 2)
    final stroke2 = Stroke(
      d: 'M50,30 L50,85',
      pts: List.generate(
        40,
        (i) => StrokePoint(50.0, 30.0 + (55.0 * i / 39.0)),
      ),
    );

    final allStrokes = [stroke1, stroke2];

    test('Valid stroke with slight human hand jitter should PASS', () {
      final userPts = List.generate(45, (i) {
        final x = 20.0 + (60.0 * i / 44.0) + (sin(i.toDouble()) * 1.5);
        final y = 30.0 + (cos(i.toDouble()) * 1.2);
        return StrokePoint(x, y);
      });

      final result = StrokeMatcher.matchAndClassify(
        rawUserPoints: userPts,
        allStrokes: allStrokes,
        currentStrokeIndex: 0,
        difficulty: DifficultyLevel.medium,
      );

      expect(result.isPass, isTrue);
      expect(result.errorReason, StrokeErrorReason.none);
    });

    test('Stroke drawn in REVERSE direction should report wrongDirection', () {
      // Draw horizontal stroke from right to left instead of left to right
      final userPts = List.generate(40, (i) {
        final x = 80.0 - (60.0 * i / 39.0);
        final y = 30.0;
        return StrokePoint(x, y);
      });

      final result = StrokeMatcher.matchAndClassify(
        rawUserPoints: userPts,
        allStrokes: allStrokes,
        currentStrokeIndex: 0,
        difficulty: DifficultyLevel.medium,
      );

      expect(result.isPass, isFalse);
      expect(result.errorReason, StrokeErrorReason.wrongDirection);
    });

    test('Drawing future stroke ahead of turn should report wrongOrder', () {
      // User draws stroke 2 (vertical stroke) when stroke 1 is expected
      final userPts = List.generate(40, (i) {
        final x = 50.0;
        final y = 30.0 + (55.0 * i / 39.0);
        return StrokePoint(x, y);
      });

      final result = StrokeMatcher.matchAndClassify(
        rawUserPoints: userPts,
        allStrokes: allStrokes,
        currentStrokeIndex: 0,
        difficulty: DifficultyLevel.medium,
      );

      expect(result.isPass, isFalse);
      expect(result.errorReason, StrokeErrorReason.wrongOrder);
      expect(result.matchedFutureIndex, 2);
    });

    test('Drawing totally different shape should report wrongShape', () {
      // Draw a circle or diagonal stroke where a horizontal stroke is expected
      final userPts = List.generate(40, (i) {
        final x = 10.0 + (80.0 * i / 39.0);
        final y = 90.0 - (80.0 * i / 39.0);
        return StrokePoint(x, y);
      });

      final result = StrokeMatcher.matchAndClassify(
        rawUserPoints: userPts,
        allStrokes: allStrokes,
        currentStrokeIndex: 0,
        difficulty: DifficultyLevel.medium,
      );

      expect(result.isPass, isFalse);
      expect(result.errorReason, StrokeErrorReason.wrongShape);
    });

    test('Accidental tiny tap should be classified as tooShort', () {
      final userPts = [
        const StrokePoint(20, 30),
        const StrokePoint(21, 30),
      ];

      final result = StrokeMatcher.matchAndClassify(
        rawUserPoints: userPts,
        allStrokes: allStrokes,
        currentStrokeIndex: 0,
        difficulty: DifficultyLevel.medium,
      );

      expect(result.isPass, isFalse);
      expect(result.errorReason, StrokeErrorReason.tooShort);
    });

    test('Small dot or tick stroke passes when placed near target', () {
      final dotStroke = Stroke(
        d: 'M40,25 L45,29',
        pts: List.generate(
          10,
          (i) => StrokePoint(40.0 + (5.0 * i / 9.0), 25.0 + (4.0 * i / 9.0)),
        ),
      );

      final userPts = [
        const StrokePoint(40.5, 25.5),
        const StrokePoint(42.0, 27.0),
        const StrokePoint(44.5, 28.5),
      ];

      final result = StrokeMatcher.matchAndClassify(
        rawUserPoints: userPts,
        allStrokes: [dotStroke],
        currentStrokeIndex: 0,
        difficulty: DifficultyLevel.medium,
      );

      expect(result.isPass, isTrue);
    });
  });
}
