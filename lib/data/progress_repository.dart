import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/character_data.dart';
import '../models/practice_progress.dart';

class UserSettings {
  final DifficultyLevel difficulty;
  final GridType gridType;
  final double strokeWidth;
  final Color strokeColor;
  final bool hapticEnabled;
  final bool soundEnabled;
  final ThemeMode themeMode;

  const UserSettings({
    this.difficulty = DifficultyLevel.medium,
    this.gridType = GridType.diagonalCross,
    this.strokeWidth = 5.0,
    this.strokeColor = const Color(0xFF1E293B),
    this.hapticEnabled = true,
    this.soundEnabled = true,
    this.themeMode = ThemeMode.system,
  });

  UserSettings copyWith({
    DifficultyLevel? difficulty,
    GridType? gridType,
    double? strokeWidth,
    Color? strokeColor,
    bool? hapticEnabled,
    bool? soundEnabled,
    ThemeMode? themeMode,
  }) {
    return UserSettings(
      difficulty: difficulty ?? this.difficulty,
      gridType: gridType ?? this.gridType,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeColor: strokeColor ?? this.strokeColor,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class ProgressRepository {
  static const _progressPrefix = 'progress_';
  static const _keyDifficulty = 'settings_difficulty';
  static const _keyGridType = 'settings_grid_type';
  static const _keyStrokeWidth = 'settings_stroke_width';
  static const _keyStrokeColor = 'settings_stroke_color';
  static const _keyHaptic = 'settings_haptic';
  static const _keySound = 'settings_sound';
  static const _keyTheme = 'settings_theme';

  final SharedPreferences _prefs;
  final Map<String, CharacterProgress> _cache = {};

  ProgressRepository(this._prefs) {
    _loadCache();
  }

  static Future<ProgressRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ProgressRepository(prefs);
  }

  void _loadCache() {
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_progressPrefix)) {
        final codepoint = key.substring(_progressPrefix.length);
        final jsonStr = _prefs.getString(key);
        if (jsonStr != null) {
          try {
            final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
            _cache[codepoint] = CharacterProgress.fromJson(jsonMap);
          } catch (_) {}
        }
      }
    }
  }

  CharacterProgress getProgress(String codepoint) {
    return _cache[codepoint] ?? CharacterProgress(codepoint: codepoint);
  }

  Future<void> recordPracticeCompletion({
    required String codepoint,
    required bool isCleanRecall, // Chế độ Tự viết (recall) và 0 lần sai/0 hint
    required int correctStrokes,
    required int wrongAttempts,
  }) async {
    final current = getProgress(codepoint);
    final updated = current.copyWith(
      practiceCount: current.practiceCount + 1,
      cleanCompletions: isCleanRecall
          ? current.cleanCompletions + 1
          : current.cleanCompletions,
      totalStrokesAttempted: current.totalStrokesAttempted + correctStrokes + wrongAttempts,
      correctStrokesCount: current.correctStrokesCount + correctStrokes,
      wrongAttemptsCount: current.wrongAttemptsCount + wrongAttempts,
      lastPracticed: DateTime.now(),
    );

    _cache[codepoint] = updated;
    await _prefs.setString(
      '$_progressPrefix$codepoint',
      jsonEncode(updated.toJson()),
    );
  }

  List<String> getMostMistakenCodepoints({int limit = 15}) {
    final list = _cache.values
        .where((p) => p.wrongAttemptsCount > 0)
        .toList()
      ..sort((a, b) => b.wrongAttemptsCount.compareTo(a.wrongAttemptsCount));
    return list.take(limit).map((p) => p.codepoint).toList();
  }

  Map<String, dynamic> getStatsSummary({
    required List<CharacterData> allHiragana,
    required List<CharacterData> allKatakana,
    required List<CharacterData> allKanji,
  }) {
    final now = DateTime.now();
    int practicedToday = 0;
    int masteredHiragana = 0;
    int masteredKatakana = 0;
    int masteredKanji = 0;

    for (final p in _cache.values) {
      if (p.lastPracticed != null &&
          p.lastPracticed!.year == now.year &&
          p.lastPracticed!.month == now.month &&
          p.lastPracticed!.day == now.day) {
        practicedToday++;
      }
    }

    for (final h in allHiragana) {
      if (getProgress(h.codepoint).masteryLevel == MasteryLevel.mastered) {
        masteredHiragana++;
      }
    }

    for (final k in allKatakana) {
      if (getProgress(k.codepoint).masteryLevel == MasteryLevel.mastered) {
        masteredKatakana++;
      }
    }

    for (final kan in allKanji) {
      if (getProgress(kan.codepoint).masteryLevel == MasteryLevel.mastered) {
        masteredKanji++;
      }
    }

    return {
      'practicedToday': practicedToday,
      'masteredHiragana': masteredHiragana,
      'masteredKatakana': masteredKatakana,
      'masteredKanji': masteredKanji,
    };
  }

  Future<void> resetAllProgress() async {
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_progressPrefix)) {
        await _prefs.remove(key);
      }
    }
    _cache.clear();
  }

  // --- Settings Persistence ---
  UserSettings loadSettings() {
    final diffIndex = _prefs.getInt(_keyDifficulty) ?? DifficultyLevel.medium.index;
    final gridIndex = _prefs.getInt(_keyGridType) ?? GridType.diagonalCross.index;
    final width = _prefs.getDouble(_keyStrokeWidth) ?? 5.0;
    final colorValue = _prefs.getInt(_keyStrokeColor) ?? 0xFF1E293B;
    final haptic = _prefs.getBool(_keyHaptic) ?? true;
    final sound = _prefs.getBool(_keySound) ?? true;
    final themeIndex = _prefs.getInt(_keyTheme) ?? ThemeMode.system.index;

    return UserSettings(
      difficulty: DifficultyLevel.values[diffIndex.clamp(0, DifficultyLevel.values.length - 1)],
      gridType: GridType.values[gridIndex.clamp(0, GridType.values.length - 1)],
      strokeWidth: width,
      strokeColor: Color(colorValue),
      hapticEnabled: haptic,
      soundEnabled: sound,
      themeMode: ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)],
    );
  }

  Future<void> saveSettings(UserSettings settings) async {
    await _prefs.setInt(_keyDifficulty, settings.difficulty.index);
    await _prefs.setInt(_keyGridType, settings.gridType.index);
    await _prefs.setDouble(_keyStrokeWidth, settings.strokeWidth);
    await _prefs.setInt(_keyStrokeColor, settings.strokeColor.toARGB32());
    await _prefs.setBool(_keyHaptic, settings.hapticEnabled);
    await _prefs.setBool(_keySound, settings.soundEnabled);
    await _prefs.setInt(_keyTheme, settings.themeMode.index);
  }
}
