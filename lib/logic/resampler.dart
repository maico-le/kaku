import 'dart:math';
import '../models/stroke.dart';

class StrokeResampler {
  /// Calculates the total arc length of a polyline.
  static double calculateArcLength(List<StrokePoint> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 1; i < points.length; i++) {
      total += points[i - 1].distanceTo(points[i]);
    }
    return total;
  }

  /// Removes consecutive points that are too close to each other (e.g. within [minDist]).
  static List<StrokePoint> filterClosePoints(
    List<StrokePoint> points, {
    double minDist = 1.5,
  }) {
    if (points.length <= 1) return points;
    final filtered = <StrokePoint>[points.first];
    for (int i = 1; i < points.length; i++) {
      if (points[i].distanceTo(filtered.last) >= minDist) {
        filtered.add(points[i]);
      }
    }
    // Always preserve the last point if it wasn't added
    if (filtered.length == 1 && points.length > 1) {
      filtered.add(points.last);
    } else if (filtered.last != points.last) {
      filtered.add(points.last);
    }
    return filtered;
  }

  /// Resamples a polyline into exactly [targetCount] equidistant points along its arc length.
  /// If the polyline has length 0 or fewer than 2 distinct points, returns [targetCount] copies of the point.
  static List<StrokePoint> resample(
    List<StrokePoint> points, {
    int targetCount = 32,
  }) {
    if (targetCount < 2) {
      throw ArgumentError('targetCount must be at least 2');
    }
    if (points.isEmpty) return [];

    if (points.length == 1) {
      return List.filled(targetCount, points.first);
    }

    // Cumulative distances
    final dists = <double>[0.0];
    for (int i = 1; i < points.length; i++) {
      dists.add(dists.last + points[i - 1].distanceTo(points[i]));
    }

    final totalLength = dists.last;
    if (totalLength < 1e-5) {
      return List.filled(targetCount, points.first);
    }

    final step = totalLength / (targetCount - 1);
    final resampled = <StrokePoint>[points.first];
    int currIdx = 0;

    for (int i = 1; i < targetCount - 1; i++) {
      final targetD = i * step;
      while (currIdx < dists.length - 1 && dists[currIdx + 1] < targetD) {
        currIdx++;
      }
      final d0 = dists[currIdx];
      final d1 = dists[currIdx + 1];
      final segLen = d1 - d0;
      if (segLen > 1e-6) {
        final alpha = (targetD - d0) / segLen;
        final x = points[currIdx].x + alpha * (points[currIdx + 1].x - points[currIdx].x);
        final y = points[currIdx].y + alpha * (points[currIdx + 1].y - points[currIdx].y);
        resampled.add(StrokePoint(x, y));
      } else {
        resampled.add(points[currIdx]);
      }
    }

    resampled.add(points.last);
    return resampled;
  }

  /// Calculates the general orientation angle in radians [-pi, pi] from start to end point.
  static double calculateOrientationAngle(StrokePoint start, StrokePoint end) {
    return atan2(end.y - start.y, end.x - start.x);
  }

  /// Calculates the minimal angular difference between two angles in radians [0, pi].
  static double angleDifference(double a1, double a2) {
    double diff = (a1 - a2).abs();
    while (diff > pi) {
      diff = (2 * pi - diff).abs();
    }
    return diff;
  }
}
