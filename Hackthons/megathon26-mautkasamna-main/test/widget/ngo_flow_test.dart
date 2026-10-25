import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/features/home/presentation/home_screen.dart';
import 'package:gullak/features/ngo/data/token_store.dart';

import '../helpers/fake_ngo_server.dart';
import '../helpers/test_support.dart';
import 'app_flow_test.dart' show tapKey;

void main() {
  Future<void> toJoinScreen(
    WidgetTester tester, {
    String lang = 'lang_en',
  }) async {
    await tapKey(tester, lang);
    await tapKey(tester, 'notice_accept');
    await tapKey(tester, 'profile_guest');
    await tapKey(tester, 'level_easy');
  }

  testWidgets('new profile joins an NGO with consent and shows as synced', (
    tester,
  ) async {
    final server = FakeNgoServer();
    final tokens = MemoryTokenStore();
    final services = await pumpGullak(
      tester,
      ngoApi: server.api(),
      tokenStore: tokens,
    );
    await toJoinScreen(tester);
    expect(find.text('Join your NGO'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('ngo_code_field')),
      'ngo-xxx-999',
    );
    await tapKey(tester, 'ngo_check');
    expect(
      find.text('We could not find this code. Check it with your teacher.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('ngo_code_field')),
      'ngo-hyd-001',
    );
    await tapKey(tester, 'ngo_check');
    expect(find.text('Green Futures Foundation'), findsOneWidget);
    expect(find.text('What is shared with your NGO'), findsOneWidget);
    // Joining needs consent first.
    await tapKey(tester, 'ngo_join');
    expect(server.byKey, isEmpty);
    await tapKey(tester, 'ngo_consent');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('ngo_join')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(server.byKey, hasLength(1));
    final studentId = server.byKey.values.single;
    expect(server.latest(studentId), isNotNull, reason: 'first report sent');
    expect(find.byKey(const ValueKey('sync_chip_synced')), findsOneWidget);
    expect(tokens.tokens, hasLength(1));

    await tapKey(tester, 'open_settings');
    expect(
      find.text('Green Futures Foundation · Ameerpet Learning Centre'),
      findsOneWidget,
    );
    expect(find.text('Student ID: $studentId'), findsOneWidget);
    final rows = await tester.runAsync(
      () => services.database.query('profile'),
    );
    expect(rows!.single['ngo_prompt_done'], 1);
  });

  testWidgets('offline: the code is saved and the map says so', (tester) async {
    final server = FakeNgoServer()..offline = true;
    await pumpGullak(tester, ngoApi: server.api());
    await toJoinScreen(tester);
    await tester.enterText(
      find.byKey(const ValueKey('ngo_code_field')),
      'NGO-HYD-001',
    );
    await tapKey(tester, 'ngo_check');
    expect(find.byKey(const ValueKey('ngo_offline')), findsOneWidget);
    expect(find.text('Save code'), findsOneWidget);
    await tapKey(tester, 'ngo_consent');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('ngo_join')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('sync_chip_offline')), findsOneWidget);
    expect(find.text('Offline · saved on phone'), findsOneWidget);
  });

  testWidgets('skipping works in Telugu and is asked only once', (
    tester,
  ) async {
    await pumpGullak(tester);
    await toJoinScreen(tester, lang: 'lang_te');
    expect(find.text('మీ NGO తో ఏమి పంచుకుంటారు'), findsNothing);
    await tapKey(tester, 'ngo_skip');
    expect(find.byType(HomeScreen), findsOneWidget);
    await tapKey(tester, 'open_settings');
    expect(find.byKey(const ValueKey('ngo_open_join')), findsOneWidget);
  });
}
