import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaku/core/constants.dart';
import 'package:kaku/logic/stroke_matcher.dart';
import 'package:kaku/models/character_data.dart';
import 'package:kaku/models/stroke.dart';

void main() {
  group('Real Kanji Data Matching & Classification Tests', () {
    late List<CharacterData> kanjiN5;
    late List<CharacterData> hiragana;

    setUpAll(() {
      // Load real JSON data from assets/data/
      final n5File = File('assets/data/kanji_n5.json');
      final n5Json = jsonDecode(n5File.readAsStringSync()) as List<dynamic>;
      kanjiN5 = n5Json
          .map((e) => CharacterData.fromJson(e as Map<String, dynamic>, WritingSystem.kanji))
          .toList();

      final hiraFile = File('assets/data/hiragana.json');
      final hiraJson = jsonDecode(hiraFile.readAsStringSync()) as List<dynamic>;
      hiragana = hiraJson
          .map((e) => CharacterData.fromJson(e as Map<String, dynamic>, WritingSystem.hiragana))
          .toList();
    });

    test('Loads 79 Kanji N5 and 75 Hiragana successfully', () {
      expect(kanjiN5.length, 79);
      expect(hiragana.length, 75);
    });

    test('Kanji 日 (4 strokes): correctly identifies wrong order and wrong direction', () {
      final hi = kanjiN5.firstWhere((k) => k.char == '日');
      expect(hi.strokeCount, 4);
      expect(hi.strokes.length, 4);

      // Stroke 1: Left vertical stroke (downward)
      final stroke1 = hi.strokes[0];
      // Stroke 2: Top-to-right box corner
      final stroke2 = hi.strokes[1];

      // Case A: User draws stroke 1 in reverse direction (bottom to top)
      final reversedStroke1 = stroke1.pts.reversed.toList();
      final resRev = StrokeMatcher.matchAndClassify(
        rawUserPoints: reversedStroke1,
        allStrokes: hi.strokes,
        currentStrokeIndex: 0,
      );
      expect(resRev.isPass, isFalse);
      expect(resRev.errorReason, StrokeErrorReason.wrongDirection);

      // Case B: User attempts stroke 2 while stroke 1 was expected (wrong order)
      final resWrongOrder = StrokeMatcher.matchAndClassify(
        rawUserPoints: stroke2.pts,
        allStrokes: hi.strokes,
        currentStrokeIndex: 0,
      );
      expect(resWrongOrder.isPass, isFalse);
      expect(resWrongOrder.errorReason, StrokeErrorReason.wrongOrder);
      expect(resWrongOrder.matchedFutureIndex, 2);

      // Case C: User draws correct stroke 1 (with slight human hand noise)
      final correctWithNoise = stroke1.pts
          .map((p) => StrokePoint(p.x + 0.8, p.y - 0.5))
          .toList();
      final resCorrect = StrokeMatcher.matchAndClassify(
        rawUserPoints: correctWithNoise,
        allStrokes: hi.strokes,
        currentStrokeIndex: 0,
      );
      expect(resCorrect.isPass, isTrue);
      expect(resCorrect.errorReason, StrokeErrorReason.none);
    });

    test('Kanji 水 (4 strokes): classifies center vertical hook, left stroke, right stroke', () {
      final mizu = kanjiN5.firstWhere((k) => k.char == '水');
      expect(mizu.strokeCount, 4);

      // Stroke 1 is center vertical hook
      final stroke1 = mizu.strokes[0];
      // Stroke 3 is left flick or right stroke
      final stroke3 = mizu.strokes[2];

      // Drawing stroke 3 first -> wrong order
      final resOrder = StrokeMatcher.matchAndClassify(
        rawUserPoints: stroke3.pts,
        allStrokes: mizu.strokes,
        currentStrokeIndex: 0,
      );
      expect(resOrder.isPass, isFalse);
      expect(resOrder.errorReason, StrokeErrorReason.wrongOrder);
      expect(resOrder.matchedFutureIndex, 3);

      // Drawing stroke 1 reversed -> wrong direction
      final resDir = StrokeMatcher.matchAndClassify(
        rawUserPoints: stroke1.pts.reversed.toList(),
        allStrokes: mizu.strokes,
        currentStrokeIndex: 0,
      );
      expect(resDir.isPass, isFalse);
      expect(resDir.errorReason, StrokeErrorReason.wrongDirection);
    });

    test('Hiragana あ (3 strokes): full practice flow verification', () {
      final aChar = hiragana.firstWhere((h) => h.char == 'あ');
      expect(aChar.strokeCount, 3);

      // Step 1: Draw stroke 1 correctly
      final s1 = aChar.strokes[0].pts.map((p) => StrokePoint(p.x + 0.5, p.y)).toList();
      final r1 = StrokeMatcher.matchAndClassify(
        rawUserPoints: s1,
        allStrokes: aChar.strokes,
        currentStrokeIndex: 0,
      );
      expect(r1.isPass, isTrue);

      // Step 2: Draw stroke 2 correctly
      final s2 = aChar.strokes[1].pts.map((p) => StrokePoint(p.x, p.y + 0.4)).toList();
      final r2 = StrokeMatcher.matchAndClassify(
        rawUserPoints: s2,
        allStrokes: aChar.strokes,
        currentStrokeIndex: 1,
      );
      expect(r2.isPass, isTrue);

      // Step 3: Draw stroke 3 correctly
      final s3 = aChar.strokes[2].pts.map((p) => StrokePoint(p.x - 0.3, p.y + 0.2)).toList();
      final r3 = StrokeMatcher.matchAndClassify(
        rawUserPoints: s3,
        allStrokes: aChar.strokes,
        currentStrokeIndex: 2,
      );
      expect(r3.isPass, isTrue);

      // All 3 strokes validated!
    });
  });
}
