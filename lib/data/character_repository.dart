import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/character_data.dart';

class CharacterRepository {
  List<CharacterData>? _hiragana;
  List<CharacterData>? _katakana;
  final Map<String, List<CharacterData>> _kanjiByLevel = {};
  final Map<String, CharacterData> _charByCodepoint = {};

  Future<void> initialize() async {
    if (_hiragana != null) return;

    // Load Hiragana
    final hiraStr = await rootBundle.loadString('assets/data/hiragana.json');
    final hiraJson = jsonDecode(hiraStr) as List<dynamic>;
    _hiragana = hiraJson
        .map((e) => CharacterData.fromJson(e as Map<String, dynamic>, WritingSystem.hiragana))
        .toList();
    for (final c in _hiragana!) {
      _charByCodepoint[c.codepoint] = c;
    }

    // Load Katakana
    final kataStr = await rootBundle.loadString('assets/data/katakana.json');
    final kataJson = jsonDecode(kataStr) as List<dynamic>;
    _katakana = kataJson
        .map((e) => CharacterData.fromJson(e as Map<String, dynamic>, WritingSystem.katakana))
        .toList();
    for (final c in _katakana!) {
      _charByCodepoint[c.codepoint] = c;
    }

    // Load Kanji sets (Extensible for N3, N2, N1)
    const kanjiLevels = ['N5', 'N4'];
    for (final level in kanjiLevels) {
      final fileKey = 'assets/data/kanji_${level.toLowerCase()}.json';
      try {
        final kanjiStr = await rootBundle.loadString(fileKey);
        final kanjiJson = jsonDecode(kanjiStr) as List<dynamic>;
        final list = kanjiJson
            .map((e) => CharacterData.fromJson(e as Map<String, dynamic>, WritingSystem.kanji))
            .toList();
        _kanjiByLevel[level] = list;
        for (final c in list) {
          _charByCodepoint[c.codepoint] = c;
        }
      } catch (e) {
        // Level file might not exist yet if user hasn't added it
      }
    }
  }

  List<CharacterData> getHiragana() => _hiragana ?? [];

  List<CharacterData> getKatakana() => _katakana ?? [];

  List<String> getAvailableKanjiLevels() => _kanjiByLevel.keys.toList();

  List<CharacterData> getKanjiByLevel(String level) => _kanjiByLevel[level] ?? [];

  List<CharacterData> getAllKanji() {
    final all = <CharacterData>[];
    for (final list in _kanjiByLevel.values) {
      all.addAll(list);
    }
    return all;
  }

  CharacterData? getByCodepoint(String codepoint) => _charByCodepoint[codepoint];

  List<CharacterData> searchKanji(String query, {String? levelFilter}) {
    final source = levelFilter != null && levelFilter != 'All'
        ? getKanjiByLevel(levelFilter)
        : getAllKanji();

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return source;

    return source.where((c) {
      if (c.char == q) return true;
      if (c.meaning != null && c.meaning!.toLowerCase().contains(q)) return true;
      if (c.onReadings.any((r) => r.toLowerCase().contains(q))) return true;
      if (c.kunReadings.any((r) => r.toLowerCase().contains(q))) return true;
      return false;
    }).toList();
  }
}
