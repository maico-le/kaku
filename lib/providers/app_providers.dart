import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/character_repository.dart';
import '../data/progress_repository.dart';
import '../models/practice_progress.dart';

final characterRepoProvider = Provider<CharacterRepository>((ref) {
  return CharacterRepository();
});

final progressRepoProvider = Provider<ProgressRepository>((ref) {
  throw UnimplementedError('progressRepoProvider must be initialized in main');
});

class SettingsNotifier extends Notifier<UserSettings> {
  @override
  UserSettings build() {
    final repo = ref.watch(progressRepoProvider);
    return repo.loadSettings();
  }

  void updateSettings(UserSettings Function(UserSettings) updater) {
    state = updater(state);
    ref.read(progressRepoProvider).saveSettings(state);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, UserSettings>(
  SettingsNotifier.new,
);

// Character data loading
final charactersLoaderProvider = FutureProvider<CharacterRepository>((ref) async {
  final repo = ref.watch(characterRepoProvider);
  await repo.initialize();
  return repo;
});

// Progress notifier to trigger reactive UI updates when practice completes
class ProgressNotifier extends Notifier<int> {
  @override
  int build() => 0;

  CharacterProgress getProgress(String codepoint) {
    return ref.watch(progressRepoProvider).getProgress(codepoint);
  }

  Future<void> recordCompletion({
    required String codepoint,
    required bool isCleanRecall,
    required int correctStrokes,
    required int wrongAttempts,
  }) async {
    await ref.read(progressRepoProvider).recordPracticeCompletion(
      codepoint: codepoint,
      isCleanRecall: isCleanRecall,
      correctStrokes: correctStrokes,
      wrongAttempts: wrongAttempts,
    );
    state++; // Notify listeners
  }

  Future<void> resetAll() async {
    await ref.read(progressRepoProvider).resetAllProgress();
    state++;
  }
}

final progressNotifierProvider = NotifierProvider<ProgressNotifier, int>(
  ProgressNotifier.new,
);

// Single character progress provider
final singleCharProgressProvider = Provider.family<CharacterProgress, String>((ref, codepoint) {
  ref.watch(progressNotifierProvider);
  final repo = ref.watch(progressRepoProvider);
  return repo.getProgress(codepoint);
});
