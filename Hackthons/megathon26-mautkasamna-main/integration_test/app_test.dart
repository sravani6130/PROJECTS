import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/app/bootstrap.dart';
import 'package:gullak/data/database/app_database.dart';
import 'package:gullak/features/story/domain/story_state.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Runs on a device or emulator with the real sqflite plugin and the real
/// database file: onboarding, all of chapter 1, then a simulated restart.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Real animations stay on here (characters bob, clouds drift), so the app
  // never "settles"; advance time in frames instead of pumpAndSettle.
  Future<void> settle(WidgetTester tester, [int ms = 3000]) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await settle(tester, 600);
    await tester.tap(finder);
    await settle(tester);
  }

  testWidgets('chapter 1 end to end with real SQLite, kept across restart', (
    tester,
  ) async {
    final path = p.join(await getDatabasesPath(), AppDatabase.fileName);
    await deleteDatabase(path);

    await tester.pumpWidget(const GullakBootstrap());
    await settle(tester);

    await tap(tester, 'lang_en');
    await tap(tester, 'notice_accept');
    await tap(tester, 'profile_guest');
    await tap(tester, 'level_easy');
    await tap(tester, 'ngo_skip');
    await tap(tester, 'play_next');

    for (var i = 0; i < 6; i++) {
      await tap(tester, 'story_next');
    }
    for (final item in ['bus', 'lunch', 'recharge', 'movie']) {
      await tap(tester, 'item_$item');
    }
    expect(find.text('Left for the gullak: ₹200'), findsOneWidget);
    await tap(tester, 'budget_submit');
    await tap(tester, 'story_next');
    await tap(tester, 'story_next');
    await tap(tester, 'opt_own');
    await tap(tester, 'pick_confirm');
    await tap(tester, 'story_next');
    for (final bin in ['left', 'left', 'left', 'right', 'left']) {
      await tap(tester, 'bin_$bin');
    }
    await tap(tester, 'activity_done');
    await tap(tester, 'story_next');
    await tap(tester, 'finish_chapter');
    expect(find.byKey(const ValueKey('chapter_complete')), findsOneWidget);

    // Query the on-device database directly.
    final db = await openDatabase(path, singleInstance: true);
    final save = (await db.query('story_save')).single;
    final story = StoryState.decode(save['state_json']! as String);
    expect(story.chapter, 2);
    expect(story.jar, 240);
    expect((await db.query('mission_progress')).single['status'], 'completed');

    // Simulate a restart: a fresh widget tree reloads state from disk and
    // skips onboarding.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const GullakBootstrap());
    await settle(tester);
    expect(find.text('1 of 7 chapters completed'), findsOneWidget);
    expect(find.text('Continue: The Laptop Dream'), findsOneWidget);
  });
}
