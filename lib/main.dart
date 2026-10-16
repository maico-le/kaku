import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'data/progress_repository.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final progressRepo = await ProgressRepository.create();

  runApp(
    ProviderScope(
      overrides: [
        progressRepoProvider.overrideWithValue(progressRepo),
      ],
      child: const KakuApp(),
    ),
  );
}

class KakuApp extends ConsumerWidget {
  const KakuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Kaku (書く)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const HomeScreen(),
    );
  }
}
