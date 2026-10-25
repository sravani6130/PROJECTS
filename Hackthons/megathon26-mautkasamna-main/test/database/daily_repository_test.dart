import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/core/localization/app_language.dart';
import 'package:gullak/features/daily/data/daily_repository.dart';
import 'package:gullak/features/daily/domain/inbox.dart';
import 'package:gullak/features/profiles/data/profile_repository.dart';
import 'package:gullak/features/progress/data/progress_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_support.dart';

void main() {
  late Database db;
  late DateTime now;
  late DailyRepository daily;
  late int profileId;

  setUp(() async {
    db = await openTestDatabase();
    now = DateTime(2026, 3, 1, 9);
    daily = DailyRepository(db, clock: () => now);
    final profiles = ProfileRepository(db, clock: () => now);
    profileId = (await profiles.getOrCreateGuest(AppLanguage.en)).id;
  });
  tearDown(() => db.close());

  void nextDay([int days = 1]) => now = now.add(Duration(days: days));

  test('one reward per day, however many taps', () async {
    expect((await daily.status(profileId)).checkedInToday, isFalse);
    final first = (await daily.checkIn(profileId))!;
    expect(first.result.total, 5);
    expect(first.result.streak, 1);
    // The messages it wrote come back, ready to show on the phone.
    expect(first.messages.single.kind, InboxKind.checkIn);
    expect(await daily.checkIn(profileId), isNull);
    // Later the same day is still the same day.
    now = now.add(const Duration(hours: 14));
    expect(await daily.checkIn(profileId), isNull);
    final status = await daily.status(profileId);
    expect(status.checkedInToday, isTrue);
    expect(status.total, 5);
    expect(status.streak, 1);
  });

  test('seven days in a row earn the week bonus; a gap restarts', () async {
    for (var d = 1; d <= 7; d++) {
      final result = (await daily.checkIn(profileId))!.result;
      expect(result.streak, d);
      expect(result.bonus, d == 7 ? 20 : 0);
      nextDay();
    }
    var status = await daily.status(profileId);
    expect(status.total, 7 * 5 + 20);
    expect(status.streak, 7, reason: 'still alive the morning after');
    expect(status.checkedInToday, isFalse);

    nextDay(); // a whole day missed
    status = await daily.status(profileId);
    expect(status.streak, 0);
    expect((await daily.checkIn(profileId))!.result.streak, 1);
    expect((await daily.status(profileId)).days, 8);
  });

  test('check-ins write inbox messages; milestones get their own', () async {
    for (var d = 1; d <= 3; d++) {
      await daily.checkIn(profileId);
      nextDay();
    }
    final inbox = await daily.inbox(profileId);
    expect(inbox.first.kind, InboxKind.streak);
    expect(inbox.first.params['streak'], 3);
    expect(inbox.where((m) => m.kind == InboxKind.checkIn), hasLength(3));
    expect(await daily.unreadCount(profileId), 4);
    await daily.markAllRead(profileId);
    expect(await daily.unreadCount(profileId), 0);
    expect((await daily.inbox(profileId)).every((m) => m.read), isTrue);
  });

  test('reminder setting starts off and remembers it was offered', () async {
    var setting = await daily.reminderSetting();
    expect(setting.enabled, isFalse);
    expect(setting.asked, isFalse);
    await daily.setReminderHour(17);
    setting = await daily.reminderSetting();
    expect(setting.hour, 17);
    expect(setting.asked, isTrue);
    await daily.setReminderHour(null);
    setting = await daily.reminderSetting();
    expect(setting.enabled, isFalse);
    expect(setting.asked, isTrue);
  });

  test('resetting progress clears check-ins and the inbox', () async {
    await daily.checkIn(profileId);
    await ProgressRepository(db).resetProfileProgress(profileId);
    expect((await daily.status(profileId)).total, 0);
    expect(await daily.inbox(profileId), isEmpty);
  });

  test('moving the clock back does not pay again', () async {
    now = DateTime(2026, 3, 5, 9);
    await daily.checkIn(profileId);
    now = DateTime(2026, 3, 4, 9);
    expect(await daily.checkIn(profileId), isNull);
    expect((await daily.status(profileId)).checkedInToday, isTrue);
  });
}
