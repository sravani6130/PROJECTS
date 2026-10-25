import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/features/home/presentation/home_screen.dart';
import 'package:gullak/features/story/data/story_repository.dart';
import 'package:gullak/features/story/domain/story_state.dart';
import 'package:gullak/features/story/presentation/chapter_screen.dart';

import 'package:gullak/app/bootstrap.dart';

import '../helpers/story_driver.dart';
import '../helpers/test_support.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Taps the app bar back button (works in every language, unlike pageBack,
/// which looks for the English tooltip).
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

/// Language → notice → guest → Easy → (no NGO code) skip.
Future<void> onboardAsGuest(
  WidgetTester tester, {
  String lang = 'lang_en',
}) async {
  await tapKey(tester, lang);
  await tapKey(tester, 'notice_accept');
  await tapKey(tester, 'profile_guest');
  await tapKey(tester, 'level_easy');
  await tapKey(tester, 'ngo_skip');
}

void main() {
  /// The saved story, read straight from the test database.
  Future<StoryState> savedStory(
    WidgetTester tester,
    AppServices services,
  ) async {
    final rows = await tester.runAsync(
      () => services.database.query('story_save'),
    );
    return StoryState.decode(rows!.single['state_json']! as String);
  }

  testWidgets('onboarding in English reaches the story map', (tester) async {
    await pumpGullak(tester);
    expect(find.text('Gullak'), findsOneWidget);
    expect(find.text('Pretend money only — no real payments.'), findsOneWidget);

    await tapKey(tester, 'lang_en');
    expect(find.text('Everything here is pretend'), findsOneWidget);
    await tapKey(tester, 'notice_accept');
    expect(find.text('Continue as guest'), findsOneWidget);
    await tapKey(tester, 'profile_guest');
    await tapKey(tester, 'level_easy');
    // Each new profile is asked once for an NGO code; it can be skipped.
    expect(find.text('Join your NGO'), findsOneWidget);
    await tapKey(tester, 'ngo_skip');

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Hi, Guest!'), findsOneWidget);
    expect(find.text('0 of 7 chapters completed'), findsOneWidget);
    expect(find.text('The Money Diaries'), findsOneWidget);
    for (var n = 1; n <= 7; n++) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('chapter_$n')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(ValueKey('chapter_$n')), findsOneWidget);
    }
    // Later chapters stay locked until the story reaches them.
    await tapKey(tester, 'chapter_7');
    expect(find.byType(ChapterScreen), findsNothing);
    expect(find.textContaining('Finish the earlier chapter'), findsOneWidget);
  });

  testWidgets('choosing Telugu shows Telugu UI and story', (tester) async {
    await pumpGullak(tester);
    await tapKey(tester, 'lang_te');
    expect(find.text('ఇక్కడ అంతా ఊహాజనితం'), findsOneWidget);
    await tapKey(tester, 'notice_accept');
    await tapKey(tester, 'profile_guest');
    await tapKey(tester, 'level_easy');
    expect(find.text('మీ NGO లో చేరండి'), findsOneWidget);
    await tapKey(tester, 'ngo_skip');
    expect(find.text('హాయ్, అతిథి!'), findsOneWidget);
    expect(find.text('మొదటి ₹1,000'), findsOneWidget);
    await tapKey(tester, 'chapter_1');
    expect(find.textContaining('ఈ వారానికి ₹1,000 ఇదిగో'), findsOneWidget);
  });

  testWidgets('nickname profile is created and greeted', (tester) async {
    await pumpGullak(tester);
    await tapKey(tester, 'lang_en');
    await tapKey(tester, 'notice_accept');
    await tester.enterText(
      find.byKey(const ValueKey('nickname_field')),
      'Meera',
    );
    await tapKey(tester, 'profile_save');
    await tapKey(tester, 'level_easy');
    await tapKey(tester, 'ngo_skip');
    expect(find.text('Hi, Meera!'), findsOneWidget);
  });

  testWidgets(
    'chapter 1: plan, over budget, missing need, decide, sort, finish',
    (tester) async {
      final services = await pumpGullak(tester);
      await onboardAsGuest(tester);
      await tapKey(tester, 'play_next');

      // Dialogue is told one line at a time.
      expect(
        find.textContaining('here is ₹1,000 for the week'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('chip_wallet')), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tapKey(tester, 'story_next');
      }

      // Budget activity: everything at once is ₹200 over.
      for (final item in [
        'bus',
        'lunch',
        'recharge',
        'movie',
        'headphones',
        'chaat',
      ]) {
        await tapKey(tester, 'item_$item');
      }
      expect(find.text('Planned ₹1,200 of ₹1,000'), findsOneWidget);
      expect(find.text('Short by ₹200'), findsOneWidget);
      await tapKey(tester, 'budget_submit');
      expect(find.textContaining('₹200 more than Asha has'), findsOneWidget);

      // Dropping a need to afford the wants is explained, not accepted.
      await tapKey(tester, 'item_lunch');
      expect(find.text('Left for the gullak: ₹50'), findsOneWidget);
      await tapKey(tester, 'budget_submit');
      expect(find.textContaining('Needs come first'), findsOneWidget);

      await tapKey(tester, 'item_lunch');
      await tapKey(tester, 'item_headphones');
      await tapKey(tester, 'item_chaat');
      expect(find.text('Left for the gullak: ₹200'), findsOneWidget);
      await tapKey(tester, 'budget_submit');

      // The plan changed the wallet, and Ravi reacts to the movie.
      expect((await savedStory(tester, services)).wallet, 200);
      expect(find.textContaining('Movie on Saturday'), findsOneWidget);
      await tapKey(tester, 'story_next');
      await tapKey(tester, 'story_next');

      // Decision with a consequence; skipping is explained and retried.
      await tapKey(tester, 'opt_skip');
      await tapKey(tester, 'pick_confirm');
      expect(find.textContaining('No form, no fair'), findsOneWidget);
      await tapKey(tester, 'pick_retry');
      await tapKey(tester, 'opt_own');
      await tapKey(tester, 'pick_confirm');
      expect(find.text('Great choice!'), findsOneWidget);

      // A double tap on Continue applies the ₹60 once.
      final next = find.byKey(const ValueKey('story_next'));
      await tester.tap(next);
      await tester.tap(next, warnIfMissed: false);
      await tester.pumpAndSettle();
      final afterForm = await savedStory(tester, services);
      expect(afterForm.wallet, 140);
      expect(afterForm.txns.where((t) => t.label == 'txn_form'), hasLength(1));

      // Sorting: a wrong bin explains itself and the card stays.
      expect(find.text('Bus pass'), findsOneWidget);
      await tapKey(tester, 'bin_right');
      expect(find.text('Think again'), findsOneWidget);
      expect(find.text('Bus pass'), findsOneWidget);
      for (final bin in ['left', 'left', 'left', 'right', 'left']) {
        await tapKey(tester, 'bin_$bin');
      }
      await tapKey(tester, 'activity_done');

      expect(find.textContaining('Opportunity cost'), findsOneWidget);
      await tapKey(tester, 'story_next');
      expect(find.text('Going into the gullak: ₹140'), findsOneWidget);
      await tapKey(tester, 'finish_chapter');

      expect(find.byKey(const ValueKey('chapter_complete')), findsOneWidget);
      expect(find.text('New badge: Budget Planner'), findsOneWidget);
      final saved = await savedStory(tester, services);
      expect(saved.chapter, 2);
      expect(saved.wallet, 0);
      expect(saved.jar, 240);

      await tapKey(tester, 'back_to_map');
      expect(find.text('1 of 7 chapters completed'), findsOneWidget);
      expect(find.textContaining('Completed ·'), findsOneWidget);
      expect(find.text('Continue: The Laptop Dream'), findsOneWidget);

      // Switching language keeps the story.
      await tapKey(tester, 'open_settings');
      await tapText(tester, 'తెలుగు');
      await goBack(tester);
      expect(find.text('7 అధ్యాయాల్లో 1 పూర్తయ్యాయి'), findsOneWidget);
      expect((await savedStory(tester, services)).jar, 240);
    },
  );

  testWidgets('replaying a finished chapter is practice and changes nothing', (
    tester,
  ) async {
    final services = await pumpGullak(tester);
    await onboardAsGuest(tester);
    await tapKey(tester, 'chapter_1');
    await StoryDriver(tester).playChapter();
    await tapKey(tester, 'back_to_map');
    final before = await savedStory(tester, services);

    await tapKey(tester, 'chapter_1');
    expect(find.text('Practice'), findsOneWidget);
    // The replay starts from the chapter's own opening money.
    final driver = StoryDriver(tester, reckless: true);
    expect(driver.s.wallet, 1000);
    await driver.playChapter();
    expect(find.byKey(const ValueKey('next_chapter')), findsNothing);
    await tapKey(tester, 'back_to_map');

    expect((await savedStory(tester, services)).encode(), before.encode());
    expect(find.text('1 of 7 chapters completed'), findsOneWidget);
  });

  testWidgets('leaving mid-chapter resumes at the same checkpoint', (
    tester,
  ) async {
    final services = await pumpGullak(tester);
    await onboardAsGuest(tester);
    await tapKey(tester, 'chapter_1');
    for (var i = 0; i < 6; i++) {
      await tapKey(tester, 'story_next');
    }
    for (final item in ['bus', 'lunch', 'recharge']) {
      await tapKey(tester, 'item_$item');
    }
    await tapKey(tester, 'budget_submit');
    await goBack(tester);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('0 of 7 chapters completed'), findsOneWidget);

    // A restart: a fresh widget tree over the same database.
    await tester.pumpWidget(const SizedBox());
    await pumpGullak(tester, services: services);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tapKey(tester, 'play_next');

    // Not back at the opening scene, and the budget is not asked again.
    expect(find.textContaining('here is ₹1,000'), findsNothing);
    expect(find.byKey(const ValueKey('budget_submit')), findsNothing);
    expect(find.textContaining('No movie, no chaat?'), findsOneWidget);
    expect((await savedStory(tester, services)).wallet, 400);
    await tester.runAsync(services.database.close);
  });

  testWidgets('progress screen and reset keep the profile', (tester) async {
    final services = await pumpGullak(tester);
    await onboardAsGuest(tester);
    await tapKey(tester, 'chapter_1');
    await StoryDriver(tester).playChapter();
    await tapKey(tester, 'back_to_map');

    await tapKey(tester, 'open_progress');
    expect(find.text('1 / 7'), findsOneWidget);
    expect(find.text('1. The First ₹1,000'), findsOneWidget);
    expect(find.text('Earned'), findsOneWidget);
    await goBack(tester);

    await tapKey(tester, 'open_settings');
    await tapKey(tester, 'reset_progress');
    await tapKey(tester, 'confirm_action');
    await goBack(tester);
    expect(find.text('Hi, Guest!'), findsOneWidget);
    expect(find.text('0 of 7 chapters completed'), findsOneWidget);
    final fresh = await tester.runAsync(
      () => StoryRepository(services.database).load(1),
    );
    expect(fresh!.state.chapter, 1);
    expect(fresh.state.wallet, 1000);
  });

  testWidgets('Stay Safe is one tap from the map', (tester) async {
    await pumpGullak(tester);
    await onboardAsGuest(tester);
    await tapKey(tester, 'stay_safe_banner');
    expect(find.text('Never share a PIN or OTP'), findsOneWidget);
    // The practice shortcut appears only once chapter 4 has been reached.
    expect(find.text('Practise: The Scholarship Message'), findsNothing);
  });

  testWidgets('the level screen can be opened again from the map', (
    tester,
  ) async {
    await pumpGullak(tester);
    await onboardAsGuest(tester);

    await tapKey(tester, 'open_levels');
    expect(find.text('Choose how to begin'), findsOneWidget);
    expect(find.text('Coming later'), findsNWidgets(2));
    // Easy is the level being played, so choosing it goes back to the map.
    await tapKey(tester, 'level_easy');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Choose how to begin'), findsNothing);

    // Also reachable from Settings.
    await tapKey(tester, 'open_settings');
    await tapKey(tester, 'settings_levels');
    expect(find.text('Choose how to begin'), findsOneWidget);
    await goBack(tester);
    expect(find.text('Settings'), findsOneWidget);
  });
}
