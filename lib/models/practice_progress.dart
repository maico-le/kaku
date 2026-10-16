enum MasteryLevel {
  notStarted, // Chưa luyện
  practicing, // Đang luyện
  mastered,   // Thuộc
}

class CharacterProgress {
  final String codepoint;
  final int practiceCount;
  final int cleanCompletions; // Hoàn thành sạch (recall mode, 0 lỗi/0 hint)
  final int totalStrokesAttempted;
  final int correctStrokesCount;
  final int wrongAttemptsCount;
  final DateTime? lastPracticed;

  const CharacterProgress({
    required this.codepoint,
    this.practiceCount = 0,
    this.cleanCompletions = 0,
    this.totalStrokesAttempted = 0,
    this.correctStrokesCount = 0,
    this.wrongAttemptsCount = 0,
    this.lastPracticed,
  });

  MasteryLevel get masteryLevel {
    if (cleanCompletions >= 3) {
      return MasteryLevel.mastered;
    }
    if (practiceCount > 0) {
      return MasteryLevel.practicing;
    }
    return MasteryLevel.notStarted;
  }

  double get accuracyRate {
    final total = correctStrokesCount + wrongAttemptsCount;
    if (total == 0) return 0.0;
    return correctStrokesCount / total;
  }

  CharacterProgress copyWith({
    int? practiceCount,
    int? cleanCompletions,
    int? totalStrokesAttempted,
    int? correctStrokesCount,
    int? wrongAttemptsCount,
    DateTime? lastPracticed,
  }) {
    return CharacterProgress(
      codepoint: codepoint,
      practiceCount: practiceCount ?? this.practiceCount,
      cleanCompletions: cleanCompletions ?? this.cleanCompletions,
      totalStrokesAttempted: totalStrokesAttempted ?? this.totalStrokesAttempted,
      correctStrokesCount: correctStrokesCount ?? this.correctStrokesCount,
      wrongAttemptsCount: wrongAttemptsCount ?? this.wrongAttemptsCount,
      lastPracticed: lastPracticed ?? this.lastPracticed,
    );
  }

  factory CharacterProgress.fromJson(Map<String, dynamic> json) {
    return CharacterProgress(
      codepoint: json['codepoint'] as String,
      practiceCount: json['practiceCount'] as int? ?? 0,
      cleanCompletions: json['cleanCompletions'] as int? ?? 0,
      totalStrokesAttempted: json['totalStrokesAttempted'] as int? ?? 0,
      correctStrokesCount: json['correctStrokesCount'] as int? ?? 0,
      wrongAttemptsCount: json['wrongAttemptsCount'] as int? ?? 0,
      lastPracticed: json['lastPracticed'] != null
          ? DateTime.tryParse(json['lastPracticed'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'codepoint': codepoint,
    'practiceCount': practiceCount,
    'cleanCompletions': cleanCompletions,
    'totalStrokesAttempted': totalStrokesAttempted,
    'correctStrokesCount': correctStrokesCount,
    'wrongAttemptsCount': wrongAttemptsCount,
    'lastPracticed': lastPracticed?.toIso8601String(),
  };
}
