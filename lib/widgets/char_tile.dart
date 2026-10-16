import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/character_data.dart';
import '../models/practice_progress.dart';
import '../providers/app_providers.dart';

class CharTile extends ConsumerWidget {
  final CharacterData character;
  final VoidCallback onTap;

  const CharTile({
    super.key,
    required this.character,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(singleCharProgressProvider(character.codepoint));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color borderColor;
    Color? badgeColor;
    switch (progress.masteryLevel) {
      case MasteryLevel.mastered:
        borderColor = AppColors.masteryMastered;
        badgeColor = AppColors.masteryMastered;
        break;
      case MasteryLevel.practicing:
        borderColor = AppColors.masteryPracticing;
        badgeColor = AppColors.masteryPracticing;
        break;
      case MasteryLevel.notStarted:
        borderColor = isDark ? const Color(0xFF33333F) : AppColors.masteryNotStarted;
        badgeColor = null;
        break;
    }

    final subLabel = character.romaji ??
        (character.meaning != null
            ? (character.meaning!.length > 9
                ? '${character.meaning!.substring(0, 8)}…'
                : character.meaning!)
            : '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: progress.masteryLevel == MasteryLevel.notStarted ? 1.0 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      character.char,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2C3E50),
                      ),
                    ),
                    if (subLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (badgeColor != null)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
