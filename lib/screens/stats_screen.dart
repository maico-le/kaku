import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../data/character_repository.dart';
import '../models/character_data.dart';
import '../providers/app_providers.dart';
import 'practice_screen.dart';

class StatsScreen extends ConsumerWidget {
  final CharacterRepository repo;

  const StatsScreen({
    super.key,
    required this.repo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressNotifierProvider);
    final progressRepo = ref.watch(progressRepoProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final summary = progressRepo.getStatsSummary(
      allHiragana: repo.getHiragana(),
      allKatakana: repo.getKatakana(),
      allKanji: repo.getAllKanji(),
    );

    final mistakenCodepoints = progressRepo.getMostMistakenCodepoints(limit: 15);
    final mistakenCharacters = mistakenCodepoints
        .map((cp) => repo.getByCodepoint(cp))
        .whereType<CharacterData>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê & Tiến độ'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Practiced Today Card
          Card(
            color: isDark ? const Color(0xFF252530) : AppColors.strokeCorrectBg,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.strokeCorrect.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.today_rounded,
                      color: AppColors.strokeCorrect,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đã luyện hôm nay',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        '${summary['practicedToday']} chữ',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Mastery breakdown by writing system
          const Text(
            'Số chữ đã thuộc (mastered)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMasteryCard(
                context,
                title: 'Hiragana',
                count: summary['masteredHiragana'] as int,
                total: repo.getHiragana().length,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 8),
              _buildMasteryCard(
                context,
                title: 'Katakana',
                count: summary['masteredKatakana'] as int,
                total: repo.getKatakana().length,
                color: Colors.teal,
              ),
              const SizedBox(width: 8),
              _buildMasteryCard(
                context,
                title: 'Kanji',
                count: summary['masteredKanji'] as int,
                total: repo.getAllKanji().length,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. Most mistaken characters section
          Row(
            children: [
              const Text(
                'Chữ hay viết sai nhất',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (mistakenCharacters.isNotEmpty)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                  label: const Text('Luyện các chữ này'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PracticeScreen(
                          character: mistakenCharacters.first,
                          playlist: mistakenCharacters,
                          initialPlaylistIndex: 0,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (mistakenCharacters.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 40, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      const Text(
                        'Chưa có chữ nào bị viết sai nhiều!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mistakenCharacters.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final c = mistakenCharacters[index];
                final progress = progressRepo.getProgress(c.codepoint);
                final accuracyPct = (progress.accuracyRate * 100).toInt();

                return Card(
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        c.char,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      c.meaning ?? c.romaji ?? c.char,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Sai ${progress.wrongAttemptsCount} lần • Tỉ lệ nét đúng: $accuracyPct%',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PracticeScreen(
                            character: c,
                            playlist: mistakenCharacters,
                            initialPlaylistIndex: index,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMasteryCard(
    BuildContext context, {
    required String title,
    required int count,
    required int total,
    required Color color,
  }) {
    final pct = total > 0 ? (count / total * 100).toInt() : 0;

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                '$count / $total',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: total > 0 ? (count / total) : 0,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                '$pct%',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
