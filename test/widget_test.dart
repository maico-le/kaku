import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaku/data/progress_repository.dart';
import 'package:kaku/main.dart';
import 'package:kaku/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Kaku app smoke test - launches and shows title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progressRepo = ProgressRepository(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepoProvider.overrideWithValue(progressRepo),
        ],
        child: const KakuApp(),
      ),
    );

    await tester.pump();

    expect(find.text('Kaku'), findsOneWidget);
    expect(find.text('書く'), findsOneWidget);
  });
}
