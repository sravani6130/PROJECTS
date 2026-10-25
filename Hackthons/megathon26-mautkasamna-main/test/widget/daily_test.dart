import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/features/daily/application/daily_providers.dart';
import 'package:gullak/features/home/presentation/home_screen.dart';

import '../helpers/story_driver.dart';
import '../helpers/test_support.dart';
import 'app_flow_test.dart' show goBack, onboardAsGuest, tapKey;

void main() {
  // A Monday morning, before the 5 PM reminder.
  var now = DateTime(2026, 3, 9, 10);
  DateTime clock() => now;
  setUp(() => now = DateTime(2026, 3, 9, 10));

  Future<void> reopenApp(WidgetTester tester) async {
    // The order Android goes through when the app is left and reopened.
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('opening the app checks in by itself, once a day', (
    tester,
  ) async {
    final reminders = FakeReminders();
    await pumpGullak(tester, reminders: reminders, clock: clock);
    await onboardAsGuest(tester);

    // Android was asked once; allowed, so reminders start on.
    expect(reminders.permissionRequests, 1);
    expect(find.textContaining('+₹5 today!'), findsOneWidget);
    expect(
      find.text('🔥 1-day streak · ₹5 pretend money saved'),
      findsOneWidget,
    );
    // The news went to the phone's notification screen...
    expect(reminders.shown, [
      'Daily check-in: ₹5 added to your Gullak. Streak day 1.',
    ]);
    // ...and into the app's own list.
    expect(find.byKey(const ValueKey('inbox_badge')), findsOneWidget);

    // Already checked in today, so the first reminder is tomorrow at 5 PM.
    final first = reminders.scheduled.first;
    expect(first.at, DateTime(2026, 3, 10, 17));
    expect(first.title, '🔥 1-day streak!');
    expect(
      first.body,
      contains('0 of 7 chapters done. Next: The First ₹1,000.'),
    );

    // Coming back the same day pays nothing more and asks nothing again.
    await reopenApp(tester);
    expect(reminders.shown, hasLength(1));
    expect(reminders.permissionRequests, 1);

    // Coming back the next day checks in again and grows the streak.
    now = DateTime(2026, 3, 10, 8);
    await reopenApp(tester);
    expect(
      find.text('🔥 2-day streak · ₹10 pretend money saved'),
      findsOneWidget,
    );
    expect(reminders.shown, hasLength(2));

    // Opening the list clears the badge.
    await tapKey(tester, 'open_inbox');
    expect(
      find.text('Daily check-in: ₹5 added to your Gullak. Streak day 2.'),
      findsOneWidget,
    );
    await goBack(tester);
    expect(find.byKey(const ValueKey('inbox_badge')), findsNothing);
  });

  testWidgets('a finished chapter goes to the phone and the in-app list', (
    tester,
  ) async {
    final reminders = FakeReminders();
    await pumpGullak(tester, reminders: reminders, clock: clock);
    await onboardAsGuest(tester);

    await tapKey(tester, 'chapter_1');
    await StoryDriver(tester).playChapter();
    await tapKey(tester, 'back_to_map');

    expect(
      reminders.shown,
      contains(startsWith('⭐ You finished Chapter 1: The First ₹1,000 with')),
    );
    expect(reminders.shown, contains(startsWith('🏅 New badge:')));
    expect(
      reminders.scheduled.first.body,
      contains('1 of 7 chapters done. Next: The Laptop Dream.'),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('open_inbox')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapKey(tester, 'open_inbox');
    expect(
      find.textContaining('You finished Chapter 1: The First ₹1,000'),
      findsOneWidget,
    );
  });

  testWidgets('blocked notifications: still checks in, reminders stay off', (
    tester,
  ) async {
    final reminders = FakeReminders()..allow = false;
    await pumpGullak(tester, reminders: reminders, clock: clock);
    await onboardAsGuest(tester);
    expect(find.textContaining('+₹5 today!'), findsOneWidget);
    expect(reminders.scheduled, isEmpty);

    await tapKey(tester, 'open_settings');
    expect(find.byKey(const ValueKey('reminder_hour')), findsNothing);
    await tapKey(tester, 'reminder_switch');
    expect(find.textContaining('Notifications are blocked'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder_hour')), findsNothing);
  });

  testWidgets('overlapping triggers never pay twice', (tester) async {
    final services = await pumpGullak(tester, clock: clock);
    await onboardAsGuest(tester);
    now = DateTime(2026, 3, 10, 8);
    final actions = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    ).read(dailyActionsProvider);
    await tester.runAsync(
      () => Future.wait([actions.autoCheckIn(), actions.autoCheckIn()]),
    );
    final rows = await tester.runAsync(
      () => services.database.query('daily_checkin'),
    );
    expect(rows, hasLength(2), reason: 'one row per day');
  });

  testWidgets('Telugu at 130% on a small phone: the card fits', (tester) async {
    await pumpGullak(
      tester,
      clock: clock,
      logicalSize: const Size(360, 640),
      textScale: 1.3,
    );
    await onboardAsGuest(tester, lang: 'lang_te');
    expect(find.byKey(const ValueKey('daily_card')), findsOneWidget);
    await tapKey(tester, 'open_inbox');
    expect(find.textContaining('రోజువారీ చెక్-ఇన్'), findsOneWidget);
    await goBack(tester);
    await tapKey(tester, 'open_settings');
    expect(find.byKey(const ValueKey('reminder_hour')), findsOneWidget);
  });
}
