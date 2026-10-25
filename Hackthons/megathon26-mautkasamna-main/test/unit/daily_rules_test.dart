import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/core/localization/app_language.dart';
import 'package:gullak/core/localization/app_strings.dart';
import 'package:gullak/features/daily/application/reminder_planner.dart';
import 'package:gullak/features/daily/domain/daily_rules.dart';

void main() {
  group('DailyRules', () {
    test('day keys use the local calendar day', () {
      expect(DailyRules.dayKey(DateTime(2026, 3, 9, 23, 59)), '2026-03-09');
      expect(DailyRules.daysBetween('2026-02-28', '2026-03-01'), 1);
      expect(DailyRules.daysBetween('2025-12-31', '2026-01-01'), 1);
    });

    test('a streak grows on consecutive days and restarts after a gap', () {
      expect(DailyRules.nextStreak(today: '2026-03-09'), 1);
      expect(
        DailyRules.nextStreak(
          lastDay: '2026-03-08',
          lastStreak: 4,
          today: '2026-03-09',
        ),
        5,
      );
      expect(
        DailyRules.nextStreak(
          lastDay: '2026-03-07',
          lastStreak: 4,
          today: '2026-03-09',
        ),
        1,
      );
    });

    test('a streak stays alive until a full day is missed', () {
      int live(String last) => DailyRules.liveStreak(
        lastDay: last,
        lastStreak: 6,
        today: '2026-03-09',
      );
      expect(live('2026-03-09'), 6);
      expect(live('2026-03-08'), 6);
      expect(live('2026-03-07'), 0);
    });

    test('every seventh day of a streak pays the week bonus', () {
      expect(DailyRules.bonusFor(6), 0);
      expect(DailyRules.bonusFor(7), DailyRules.weeklyBonus);
      expect(DailyRules.bonusFor(14), DailyRules.weeklyBonus);
      const before = DailyStatus(
        today: 'x',
        checkedInToday: false,
        streak: 6,
        total: 30,
        days: 6,
      );
      expect(before.nextReward, 25);
      expect(before.weekProgress, 6);
    });

    test('week dots: full on day 7, empty again the next day', () {
      DailyStatus s(int streak, bool today) => DailyStatus(
        today: 'x',
        checkedInToday: today,
        streak: streak,
        total: 0,
        days: streak,
      );
      expect(s(7, true).weekProgress, 7);
      expect(s(7, false).weekProgress, 0);
      expect(s(8, true).weekProgress, 1);
      expect(s(0, false).weekProgress, 0);
    });
  });

  group('planReminders', () {
    final en = (jsonDecode(
      File('assets/content/translations/en.json').readAsStringSync(),
    ) as Map).cast<String, String>();
    final t = AppStrings(AppLanguage.en, {AppLanguage.en: en});

    List<String> plan(DateTime now, DailyStatus status, {String? next}) => [
      for (final r in planReminders(
        now: now,
        hour: 17,
        status: status,
        t: t,
        chaptersDone: 2,
        chapterCount: 7,
        nextChapterTitle: next,
      ))
        '${r.at.day} ${r.at.hour}: ${r.title} | ${r.body}',
    ];

    DailyStatus status({required int streak, required bool today}) =>
        DailyStatus(
          today: '2026-03-09',
          checkedInToday: today,
          streak: streak,
          total: 0,
          days: streak,
        );

    test('not checked in yet: today warns the streak is at stake', () {
      final lines = plan(
        DateTime(2026, 3, 9, 10),
        status(streak: 3, today: false),
        next: 'The Bank Visit',
      );
      expect(lines, hasLength(3));
      expect(lines[0], startsWith('9 17: 🔥 3-day streak!'));
      expect(lines[0], contains('₹5 so your streak keeps going'));
      expect(lines[0], contains('2 of 7 chapters done. Next: The Bank Visit.'));
      // By tomorrow the streak would already be broken.
      expect(lines[1], startsWith('10 17: Your Gullak is waiting'));
      expect(lines[2], contains('We miss you'));
    });

    test('already checked in: nothing today, tomorrow keeps the streak', () {
      final lines = plan(
        DateTime(2026, 3, 9, 10),
        status(streak: 6, today: true),
      );
      expect(lines.first, startsWith('10 17: 🔥 6-day streak!'));
      // Day 7 of the streak carries the week bonus.
      expect(lines.first, contains('₹25'));
      expect(lines.every((l) => !l.startsWith('9 ')), isTrue);
    });

    test('after the reminder time, today is skipped', () {
      final lines = plan(
        DateTime(2026, 3, 9, 18),
        status(streak: 0, today: false),
      );
      expect(lines.first, startsWith('10 17:'));
      expect(lines, hasLength(2));
    });
  });
}
