import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/core/audio/narrator.dart';

import '../helpers/story_driver.dart';
import '../helpers/test_support.dart';
import 'app_flow_test.dart' show goBack, onboardAsGuest, tapKey;

void main() {
  final speaker = find.byKey(const ValueKey('speak_button'));

  testWidgets('story lines, choices and feedback are read aloud', (
    tester,
  ) async {
    final narrator = RecordingNarrator();
    await pumpGullak(tester, narrator: narrator);
    // Nothing is spoken before a profile exists.
    expect(speaker, findsNothing);
    await onboardAsGuest(tester);
    narrator.said.clear();

    await tapKey(tester, 'chapter_1');
    // The first line is spoken as it appears, and has a speaker to replay it.
    expect(narrator.said, isNotEmpty);
    final first = narrator.said.last;
    expect(first, contains('₹1,000'));
    expect(speaker, findsOneWidget);
    // Tapping while it plays stops it; tapping again replays it.
    await tester.tap(speaker);
    await tester.pump();
    expect(narrator.speaking.value, isNull);
    await tester.tap(speaker);
    await tester.pump();
    expect(narrator.said.last, first);

    // Each new line is spoken in turn.
    await tapKey(tester, 'story_next');
    expect(narrator.said.last, isNot(first));

    // Play the chapter, checking the decision and the lesson on the way.
    var sawPick = false;
    var sawTeach = false;
    await StoryDriver(
      tester,
      onBeat: (label) async {
        if (label.endsWith('c1_form')) {
          sawPick = true;
          // Every option has its own speaker.
          final option = find.byWidgetPredicate(
            (w) => '${w.key}'.contains("'opt_"),
          );
          expect(option, findsWidgets);
          expect(
            find.descendant(of: option.first, matching: speaker),
            findsOneWidget,
          );
        }
        if (label.endsWith('teach')) {
          sawTeach = true;
          // Gullu reads the whole lesson, not just the heading.
          expect(narrator.said.last, startsWith('What this teaches'));
          expect(narrator.said.last, contains('A budget is a plan'));
        }
      },
    ).playChapter();
    expect(sawPick && sawTeach, isTrue);
    // Feedback after a decision is read out when it appears.
    expect(
      narrator.said.where((s) => s.startsWith(RegExp('Great choice|Here'))),
      isNotEmpty,
    );
  });

  testWidgets('the speaker switch in settings turns reading aloud off', (
    tester,
  ) async {
    final narrator = RecordingNarrator();
    final services = await pumpGullak(tester, narrator: narrator);
    await onboardAsGuest(tester);

    await tapKey(tester, 'open_settings');
    expect(find.byKey(const ValueKey('read_aloud_pace')), findsOneWidget);
    await tapKey(tester, 'read_aloud_switch');
    expect(find.byKey(const ValueKey('read_aloud_pace')), findsNothing);
    final rows = await tester.runAsync(
      () => services.database.query('profile', columns: ['read_aloud']),
    );
    expect(rows!.single['read_aloud'], 'off');
    await goBack(tester);

    narrator.said.clear();
    await tapKey(tester, 'chapter_1');
    expect(narrator.said, isEmpty);
    expect(speaker, findsNothing);
    await goBack(tester);

    // Back on, at normal pace.
    await tapKey(tester, 'open_settings');
    await tapKey(tester, 'read_aloud_switch');
    await tester.tap(find.text('Normal'));
    await tester.pumpAndSettle();
    final again = await tester.runAsync(
      () => services.database.query('profile', columns: ['read_aloud']),
    );
    expect(again!.single['read_aloud'], ReadAloud.normal.name);
  });

  testWidgets('settings warn when the phone has no voice for the language', (
    tester,
  ) async {
    final narrator = RecordingNarrator()..voiceAvailable = false;
    await pumpGullak(tester, narrator: narrator);
    await onboardAsGuest(tester, lang: 'lang_te');
    await tapKey(tester, 'open_settings');
    expect(find.byKey(const ValueKey('read_aloud_no_voice')), findsOneWidget);
  });

  test('symbols a voice would spell out are dropped', () {
    expect(cleanForSpeech('Save ₹200 → jar • now'), 'Save ₹200 jar now');
  });
}
