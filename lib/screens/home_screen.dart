import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../data/character_repository.dart';
import '../models/character_data.dart';
import '../providers/app_providers.dart';
import '../widgets/char_tile.dart';
import 'practice_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedKanjiLevel = 'N5';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openPractice(CharacterData char, List<CharacterData> playlist) {
    final initialIndex = playlist.indexWhere((c) => c.codepoint == char.codepoint);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticeScreen(
          character: char,
          playlist: playlist,
          initialPlaylistIndex: max(0, initialIndex),
        ),
      ),
    );
  }

  void _practiceRandom(List<CharacterData> pool) {
    if (pool.isEmpty) return;
    final randomChar = pool[Random().nextInt(pool.length)];
    _openPractice(randomChar, pool);
  }

  @override
  Widget build(BuildContext context) {
    final charactersAsync = ref.watch(charactersLoaderProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Kaku',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(width: 6),
            const Text(
              '書く',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.normal,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Hiragana'),
            Tab(text: 'Katakana'),
            Tab(text: 'Kanji'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Thống kê',
            onPressed: () {
              charactersAsync.whenData((repo) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StatsScreen(repo: repo),
                  ),
                );
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Cài đặt',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: charactersAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang nạp dữ liệu KanjiVG...'),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Text('Lỗi nạp dữ liệu: $err'),
        ),
        data: (repo) {
          return TabBarView(
            controller: _tabController,
            children: [
              // 1. Hiragana Tab
              _buildKanaTab(repo.getHiragana(), 'Hiragana'),
              // 2. Katakana Tab
              _buildKanaTab(repo.getKatakana(), 'Katakana'),
              // 3. Kanji Tab
              _buildKanjiTab(repo),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKanaTab(List<CharacterData> kanaList, String title) {
    // Group characters by their designated row/group
    final groups = <String, List<CharacterData>>{};
    for (final c in kanaList) {
      groups.putIfAbsent(c.group, () => []).add(c);
    }

    return Column(
      children: [
        // Top Toolbar: Random Practice button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                '${kanaList.length} ký tự',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Luyện ngẫu nhiên'),
                onPressed: () => _practiceRandom(kanaList),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: groups.keys.length,
            itemBuilder: (context, index) {
              final groupName = groups.keys.elementAt(index);
              final groupChars = groups[groupName]!;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _formatGroupName(groupName),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.playlist_play_rounded, size: 18),
                            label: const Text('Luyện cả hàng', style: TextStyle(fontSize: 12)),
                            onPressed: () => _openPractice(groupChars.first, groupChars),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: groupChars.length,
                        itemBuilder: (context, cIdx) {
                          final c = groupChars[cIdx];
                          return CharTile(
                            character: c,
                            onTap: () => _openPractice(c, groupChars),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKanjiTab(CharacterRepository repo) {
    final availableLevels = repo.getAvailableKanjiLevels();
    final kanjiList = repo.searchKanji(
      _searchQuery,
      levelFilter: _selectedKanjiLevel,
    );

    return Column(
      children: [
        // Search & Filter header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              // Level Selector
              DropdownButton<String>(
                value: _selectedKanjiLevel,
                items: [
                  for (final lvl in availableLevels)
                    DropdownMenuItem(value: lvl, child: Text(lvl)),
                  const DropdownMenuItem(value: 'All', child: Text('Tất cả')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedKanjiLevel = val;
                    });
                  }
                },
              ),
              const SizedBox(width: 10),
              // Search field
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm chữ, nghĩa, on, kun...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        // Random button & count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${kanjiList.length} Kanji',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Luyện ngẫu nhiên'),
                onPressed: () => _practiceRandom(kanjiList),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Grid of Kanji
        Expanded(
          child: kanjiList.isEmpty
              ? const Center(child: Text('Không tìm thấy kanji phù hợp'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: kanjiList.length,
                  itemBuilder: (context, index) {
                    final k = kanjiList[index];
                    return CharTile(
                      character: k,
                      onTap: () => _openPractice(k, kanjiList),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatGroupName(String name) {
    switch (name) {
      case 'a-row':
        return 'Hàng A (あ・ア)';
      case 'ka-row':
        return 'Hàng Ka (か・カ)';
      case 'sa-row':
        return 'Hàng Sa (さ・サ)';
      case 'ta-row':
        return 'Hàng Ta (た・タ)';
      case 'na-row':
        return 'Hàng Na (な・ナ)';
      case 'ha-row':
        return 'Hàng Ha (は・ハ)';
      case 'ma-row':
        return 'Hàng Ma (ま・マ)';
      case 'ya-row':
        return 'Hàng Ya (や・ヤ)';
      case 'ra-row':
        return 'Hàng Ra (ら・ラ)';
      case 'wa-row':
        return 'Hàng Wa (わ・ワ)';
      case 'n-row':
        return 'Âm mũi (ん・ン)';
      case 'dakuten':
        return 'Biến âm Đục (が, ざ, だ, ば...)';
      case 'handakuten':
        return 'Biến âm Bán đục (ぱ, ぴ, ぷ...)';
      case 'small':
        return 'Âm ghép & Ký tự nhỏ (っ, ゃ, ゅ, ょ...)';
      default:
        return name;
    }
  }
}
