import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: ListView(
        children: [
          // 1. Difficulty
          _buildSectionHeader('Độ khó chấm nét'),
          _buildDifficultyTile(
            title: 'Dễ (Easy)',
            subtitle: 'Khoan dung cao, phù hợp cho người mới bắt đầu',
            level: DifficultyLevel.easy,
            current: settings.difficulty,
            onSelect: () => settingsNotifier.updateSettings((s) => s.copyWith(difficulty: DifficultyLevel.easy)),
          ),
          _buildDifficultyTile(
            title: 'Vừa (Medium) - Mặc định',
            subtitle: 'Cân bằng giữa độ chính xác và tính tự nhiên khi vẽ',
            level: DifficultyLevel.medium,
            current: settings.difficulty,
            onSelect: () => settingsNotifier.updateSettings((s) => s.copyWith(difficulty: DifficultyLevel.medium)),
          ),
          _buildDifficultyTile(
            title: 'Chặt (Strict)',
            subtitle: 'Yêu cầu chuẩn xác cao về độ dài, góc và vị trí',
            level: DifficultyLevel.strict,
            current: settings.difficulty,
            onSelect: () => settingsNotifier.updateSettings((s) => s.copyWith(difficulty: DifficultyLevel.strict)),
          ),
          const Divider(),

          // 2. Grid Style
          _buildSectionHeader('Lưới tham chiếu tập viết'),
          ListTile(
            title: const Text('Kiểu lưới ô vẽ'),
            subtitle: Text(_formatGridTypeName(settings.gridType)),
            trailing: const Icon(Icons.grid_on_rounded),
            onTap: () => _showGridTypePicker(context, ref, settings.gridType),
          ),
          const Divider(),

          // 3. Drawing Stroke Settings
          _buildSectionHeader('Nét vẽ'),
          ListTile(
            title: const Text('Độ dày nét'),
            subtitle: Slider(
              value: settings.strokeWidth,
              min: 3.0,
              max: 9.0,
              divisions: 6,
              label: '${settings.strokeWidth.toInt()} px',
              onChanged: (val) {
                settingsNotifier.updateSettings((s) => s.copyWith(strokeWidth: val));
              },
            ),
            trailing: Text('${settings.strokeWidth.toInt()} px'),
          ),
          const Divider(),

          // 4. Feedback (Haptic & Audio)
          _buildSectionHeader('Phản hồi giác quan'),
          SwitchListTile(
            title: const Text('Rung phản hồi (Haptic)'),
            subtitle: const Text('Rung nhẹ khi vẽ đúng, rung rõ khi vẽ sai'),
            value: settings.hapticEnabled,
            onChanged: (val) {
              settingsNotifier.updateSettings((s) => s.copyWith(hapticEnabled: val));
            },
          ),
          SwitchListTile(
            title: const Text('Âm thanh phản hồi (Sound)'),
            subtitle: const Text('Phát âm thanh click khi vẽ đúng nét'),
            value: settings.soundEnabled,
            onChanged: (val) {
              settingsNotifier.updateSettings((s) => s.copyWith(soundEnabled: val));
            },
          ),
          const Divider(),

          // 5. Appearance (Theme)
          _buildSectionHeader('Giao diện'),
          ListTile(
            title: const Text('Chế độ sáng / tối'),
            subtitle: Text(_formatThemeModeName(settings.themeMode)),
            trailing: const Icon(Icons.brightness_medium_rounded),
            onTap: () => _showThemePicker(context, ref, settings.themeMode),
          ),
          const Divider(),

          // 6. Data management
          _buildSectionHeader('Dữ liệu cá nhân'),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: const Text(
              'Xóa toàn bộ tiến độ',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Đặt lại số lần luyện và mức thành thạo của tất cả chữ'),
            onTap: () => _confirmResetProgress(context, ref),
          ),
          const Divider(),

          // 7. About & Credits
          _buildSectionHeader('Thông tin & Ghi công bản quyền'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Giới thiệu & Giấy phép dữ liệu'),
            subtitle: const Text('KanjiVG, KANJIDIC2 (CC BY-SA 3.0)'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showAboutDialog(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDifficultyTile({
    required String title,
    required String subtitle,
    required DifficultyLevel level,
    required DifficultyLevel current,
    required VoidCallback onSelect,
  }) {
    final isSelected = level == current;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      subtitle: Text(subtitle),
      leading: Icon(
        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
        color: isSelected ? AppColors.primary : Colors.grey,
      ),
      onTap: onSelect,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  String _formatGridTypeName(GridType type) {
    switch (type) {
      case GridType.diagonalCross:
        return 'Chữ thập + Đường chéo (Mễ tự cách)';
      case GridType.crossOnly:
        return 'Chữ thập (Thập tự cách)';
      case GridType.nineBoxes:
        return 'Lưới 9 ô (Cửu cung cách)';
      case GridType.none:
        return 'Không hiển thị lưới';
    }
  }

  String _formatThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Theo hệ thống';
      case ThemeMode.light:
        return 'Giao diện Sáng (Light)';
      case ThemeMode.dark:
        return 'Giao diện Tối (Dark)';
    }
  }

  void _showGridTypePicker(BuildContext context, WidgetRef ref, GridType current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final type in GridType.values)
                ListTile(
                  title: Text(_formatGridTypeName(type)),
                  leading: Icon(
                    type == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: type == current ? AppColors.primary : Colors.grey,
                  ),
                  onTap: () {
                    ref.read(settingsProvider.notifier).updateSettings((s) => s.copyWith(gridType: type));
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in ThemeMode.values)
                ListTile(
                  title: Text(_formatThemeModeName(mode)),
                  leading: Icon(
                    mode == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: mode == current ? AppColors.primary : Colors.grey,
                  ),
                  onTap: () {
                    ref.read(settingsProvider.notifier).updateSettings((s) => s.copyWith(themeMode: mode));
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmResetProgress(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa toàn bộ tiến độ?'),
        content: const Text(
          'Hành động này sẽ xóa vĩnh viễn tất cả kết quả luyện viết, số lần hoàn thành và thống kê chữ thuộc.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(progressNotifierProvider.notifier).resetAll();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã đặt lại toàn bộ tiến độ')),
                );
              }
            },
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('Kaku (書く)'),
            SizedBox(width: 8),
            Text('v1.0.0', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ứng dụng luyện viết chữ Nhật (Hiragana, Katakana, Kanji JLPT N5 & N4) bằng ngón tay với thuật toán so khớp thứ tự và hướng nét KanjiVG chuẩn xác.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                'Ghi công dữ liệu & Giấy phép:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                '• KanjiVG: Bản quyền © 2009-2026 Ulrich Apel. Dữ liệu nét chữ SVG phát hành theo giấy phép Creative Commons Attribution-Share Alike 3.0 (CC BY-SA 3.0).\n'
                'Trang chủ: https://kanjivg.tagaini.net/\n\n'
                '• KANJIDIC2 & kanjiapi.dev: Từ điển Hán tự và nghĩa phát hành theo giấy phép Creative Commons Attribution-Share Alike 3.0 (CC BY-SA 3.0) của Electronic Dictionary Research and Development Group (EDRDG).\n\n'
                '• Font chữ: Noto Sans JP (Google Fonts) theo giấy phép Open Font License (OFL).\n\n'
                'Hoạt động ngoại tuyến 100%, bảo vệ quyền riêng tư.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
