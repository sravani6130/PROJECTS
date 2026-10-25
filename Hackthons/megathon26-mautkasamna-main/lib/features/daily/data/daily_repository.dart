import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/utils/ids.dart';
import '../domain/daily_rules.dart';
import '../domain/inbox.dart';

/// Daily check-ins (DAILY_CHECKIN), the in-app inbox (INBOX) and the
/// device's reminder setting (APP_STATE).
class DailyRepository {
  DailyRepository(this._db, {Clock? clock}) : _clock = clock ?? DateTime.now;

  final Database _db;
  final Clock _clock;

  String get _today => DailyRules.dayKey(_clock());

  // --- Check-in -------------------------------------------------------------

  Future<DailyStatus> status(int profileId) => _status(_db, profileId);

  Future<DailyStatus> _status(DatabaseExecutor db, int profileId) async {
    final today = _today;
    final last = await db.query(
      'daily_checkin',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'day DESC',
      limit: 1,
    );
    final sums = await db.rawQuery(
      'SELECT COUNT(*) AS days, COALESCE(SUM(reward + bonus), 0) AS total '
      'FROM daily_checkin WHERE profile_id = ?',
      [profileId],
    );
    final lastDay = last.isEmpty ? null : last.single['day']! as String;
    final lastStreak = last.isEmpty ? 0 : last.single['streak']! as int;
    return DailyStatus(
      today: today,
      // A check-in dated after today (the phone's clock went back) counts
      // as today's, so changing the clock can't pay twice.
      checkedInToday: lastDay != null && lastDay.compareTo(today) >= 0,
      streak: DailyRules.liveStreak(
        lastDay: lastDay,
        lastStreak: lastStreak,
        today: today,
      ),
      total: sums.single['total']! as int,
      days: sums.single['days']! as int,
    );
  }

  /// Claims today's reward with the inbox messages it wrote (in the same
  /// transaction). Returns null if today was already claimed, so it can
  /// never pay twice.
  Future<({CheckIn result, List<InboxMessage> messages})?> checkIn(
    int profileId,
  ) {
    return _db.transaction((txn) async {
      final today = _today;
      final last = await txn.query(
        'daily_checkin',
        where: 'profile_id = ?',
        whereArgs: [profileId],
        orderBy: 'day DESC',
        limit: 1,
      );
      final lastDay = last.isEmpty ? null : last.single['day']! as String;
      if (lastDay != null && lastDay.compareTo(today) >= 0) return null;
      final streak = DailyRules.nextStreak(
        lastDay: lastDay,
        lastStreak: last.isEmpty ? 0 : last.single['streak']! as int,
        today: today,
      );
      final result = CheckIn(
        reward: DailyRules.dailyReward,
        bonus: DailyRules.bonusFor(streak),
        streak: streak,
      );
      final inserted = await txn.insert('daily_checkin', {
        'profile_id': profileId,
        'day': today,
        'reward': result.reward,
        'bonus': result.bonus,
        'streak': streak,
        'claimed_at': isoNow(_clock),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (inserted == 0) return null;
      final messages = [
        await _addMessage(txn, profileId, InboxKind.checkIn, {
          'reward': result.reward,
          'streak': streak,
        }),
        if (result.bonus > 0)
          await _addMessage(txn, profileId, InboxKind.weekBonus, {
            'bonus': result.bonus,
            'streak': streak,
          })
        else if (DailyRules.milestones.contains(streak))
          await _addMessage(txn, profileId, InboxKind.streak, {
            'streak': streak,
          }),
      ];
      return (result: result, messages: messages);
    });
  }

  // --- Inbox -----------------------------------------------------------------

  Future<InboxMessage> addMessage(
    int profileId,
    InboxKind kind, [
    Map<String, Object> params = const {},
  ]) => _addMessage(_db, profileId, kind, params);

  Future<InboxMessage> _addMessage(
    DatabaseExecutor db,
    int profileId,
    InboxKind kind,
    Map<String, Object> params,
  ) async {
    final id = await db.insert('inbox', {
      'profile_id': profileId,
      'kind': kind.name,
      'params': jsonEncode(params),
      'created_at': isoNow(_clock),
    });
    return InboxMessage(
      id: id,
      kind: kind,
      params: params,
      createdAt: _clock(),
      read: false,
    );
  }

  /// Newest first. Older messages beyond [limit] are kept but not shown.
  Future<List<InboxMessage>> inbox(int profileId, {int limit = 60}) async {
    final rows = await _db.query(
      'inbox',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'inbox_id DESC',
      limit: limit,
    );
    return [
      for (final row in rows)
        if (InboxKind.parse(row['kind']! as String) case final kind?)
          InboxMessage(
            id: row['inbox_id']! as int,
            kind: kind,
            params: (jsonDecode(row['params']! as String) as Map)
                .cast<String, Object>(),
            createdAt: DateTime.parse(row['created_at']! as String),
            read: row['read_at'] != null,
          ),
    ];
  }

  Future<int> unreadCount(int profileId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM inbox WHERE profile_id = ? AND read_at IS NULL',
      [profileId],
    );
    return rows.single['n']! as int;
  }

  Future<void> markAllRead(int profileId) => _db.update(
    'inbox',
    {'read_at': isoNow(_clock)},
    where: 'profile_id = ? AND read_at IS NULL',
    whereArgs: [profileId],
  );

  // --- Reminder setting ---------------------------------------------------

  Future<ReminderSetting> reminderSetting() async {
    final rows = await _db.query('app_state', where: 'id = 1');
    if (rows.isEmpty) return const ReminderSetting();
    return ReminderSetting(
      hour: rows.single['reminder_hour'] as int?,
      asked: rows.single['reminder_asked'] == 1,
    );
  }

  /// Saves the reminder hour (null turns reminders off) and records that the
  /// player has been asked.
  Future<void> setReminderHour(int? hour) async {
    final values = {
      'reminder_hour': hour,
      'reminder_asked': 1,
      'updated_at': isoNow(_clock),
    };
    final updated = await _db.update('app_state', values, where: 'id = 1');
    if (updated == 0) await _db.insert('app_state', {'id': 1, ...values});
  }
}

/// Device-wide phone reminder choice.
class ReminderSetting {
  const ReminderSetting({this.hour, this.asked = false});

  /// Local hour of the daily reminder, or null when reminders are off.
  final int? hour;
  final bool asked;

  bool get enabled => hour != null;

  static const defaultHour = 17;
}
