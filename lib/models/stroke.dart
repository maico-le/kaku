import 'dart:math';

/// A 2D point representation for stroke analysis.
class StrokePoint {
  final double x;
  final double y;

  const StrokePoint(this.x, this.y);

  double distanceTo(StrokePoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  StrokePoint copyWith({double? x, double? y}) {
    return StrokePoint(x ?? this.x, y ?? this.y);
  }

  factory StrokePoint.fromJson(List<dynamic> json) {
    return StrokePoint(
      (json[0] as num).toDouble(),
      (json[1] as num).toDouble(),
    );
  }

  List<double> toJson() => [x, y];

  @override
  String toString() => '($x, $y)';
}

/// A stroke consisting of the original SVG path data and sampled polyline points.
class Stroke {
  final String d;
  final List<StrokePoint> pts;

  const Stroke({
    required this.d,
    required this.pts,
  });

  factory Stroke.fromJson(Map<String, dynamic> json) {
    final ptsList = (json['pts'] as List<dynamic>)
        .map((p) => StrokePoint.fromJson(p as List<dynamic>))
        .toList();
    return Stroke(
      d: json['d'] as String,
      pts: ptsList,
    );
  }

  Map<String, dynamic> toJson() => {
    'd': d,
    'pts': pts.map((p) => p.toJson()).toList(),
  };
}
