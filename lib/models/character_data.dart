import 'stroke.dart';

enum WritingSystem {
  hiragana,
  katakana,
  kanji,
}

class CharacterData {
  final String char;
  final String codepoint;
  final WritingSystem system;
  final String group; // e.g. 'a-row', 'ka-row' or 'N5', 'N4'
  final String? romaji;
  final String? meaning;
  final List<String> onReadings;
  final List<String> kunReadings;
  final int strokeCount;
  final List<Stroke> strokes;

  const CharacterData({
    required this.char,
    required this.codepoint,
    required this.system,
    required this.group,
    this.romaji,
    this.meaning,
    this.onReadings = const [],
    this.kunReadings = const [],
    required this.strokeCount,
    required this.strokes,
  });

  factory CharacterData.fromJson(Map<String, dynamic> json, WritingSystem system) {
    final strokesList = (json['strokes'] as List<dynamic>)
        .map((s) => Stroke.fromJson(s as Map<String, dynamic>))
        .toList();

    return CharacterData(
      char: json['char'] as String,
      codepoint: json['codepoint'] as String,
      system: system,
      group: (json['group'] ?? json['level'] ?? '') as String,
      romaji: json['romaji'] as String?,
      meaning: json['meaning'] as String?,
      onReadings: json['on'] != null
          ? List<String>.from(json['on'] as List<dynamic>)
          : const [],
      kunReadings: json['kun'] != null
          ? List<String>.from(json['kun'] as List<dynamic>)
          : const [],
      strokeCount: json['strokeCount'] as int? ?? strokesList.length,
      strokes: strokesList,
    );
  }
}
