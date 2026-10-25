import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/features/home/presentation/home_screen.dart';
import 'package:gullak/features/story/domain/story_state.dart';

import '../helpers/story_driver.dart';
import '../helpers/test_support.dart';
import 'app_flow_test.dart' show onboardAsGuest, tapKey;

/// Plays the whole story through the real UI. Any layout overflow, missing
/// widget or dead end fails the test.
void main() {
  Future<StoryState> playAll(
    WidgetTester tester, {
    required String lang,
    required bool reckless,
    Size size = const Size(432, 960),
    double textScale = 1.0,
  }) async {
    final services = await pumpGullak(
      tester,
      logicalSize: size,
      textScale: textScale,
    );
    await onboardAsGuest(tester, lang: lang);
    await tapKey(tester, 'play_next');
    final driver = StoryDriver(tester, reckless: reckless);
    for (var chapter = 1; chapter <= StoryState.chapterCount; chapter++) {
      expect(driver.play.chapter.number, chapter);
      expect(driver.play.practice, isFalse);
      await driver.playChapter();
      expect(find.byKey(const ValueKey('chapter_complete')), findsOneWidget);
      if (chapter < StoryState.chapterCount) {
        await driver.tap('next_chapter');
      }
    }
    expect(find.byKey(const ValueKey('next_chapter')), findsNothing);
    await driver.tap('back_to_map');
    expect(find.byType(HomeScreen), findsOneWidget);
    final row = await tester.runAsync(
      () => services.database.query('story_save'),
    );
    return StoryState.decode(row!.single['state_json']! as String);
  }

  testWidgets('careful play-through in English', (tester) async {
    final s = await playAll(tester, lang: 'lang_en', reckless: false);
    expect(s.finished, isTrue);
    expect(s.done.length, 7);
    expect(s.debt, 0);
    expect(s.n('c4_unsafe'), 0);
    expect(find.text('7 of 7 chapters completed'), findsOneWidget);
    expect(find.text('View my progress'), findsOneWidget);
  });

  testWidgets('reckless play-through: every mistake has a way back', (
    tester,
  ) async {
    final s = await playAll(tester, lang: 'lang_en', reckless: true);
    expect(s.finished, isTrue);
    expect(s.done.length, 7);
    expect(s.flag('c5_item'), 'nova');
    expect(s.flag('c3_pending'), 'double');
    expect(s.n('c4_unsafe'), 4);
    expect(s.debt, greaterThan(0));
    for (final balance in [s.wallet, s.jar, s.bank, s.fd]) {
      expect(balance, greaterThanOrEqualTo(0));
    }
  });

  testWidgets('Telugu at 130% text on a small phone: no clipped layouts', (
    tester,
  ) async {
    final s = await playAll(
      tester,
      lang: 'lang_te',
      reckless: true,
      size: const Size(360, 640),
      textScale: 1.3,
    );
    expect(s.finished, isTrue);
  });

  testWidgets('Telugu careful play-through on a small phone', (tester) async {
    final s = await playAll(
      tester,
      lang: 'lang_te',
      reckless: false,
      size: const Size(360, 640),
      textScale: 1.3,
    );
    expect(s.finished, isTrue);
  });
}
