import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../../core/utils/ids.dart';
import 'snapshot_repository.dart';

/// A report waiting for the server (SYNC_OUTBOX).
class OutboxItem {
  const OutboxItem({
    required this.profileId,
    required this.revision,
    required this.content,
    required this.attempts,
    this.nextAttemptAt,
  });

  factory OutboxItem.fromRow(Map<String, Object?> row) => OutboxItem(
    profileId: row['profile_id']! as int,
    revision: row['revision']! as int,
    content: row['content']! as String,
    attempts: row['attempts']! as int,
    nextAttemptAt: DateTime.tryParse(row['next_attempt_at'] as String? ?? ''),
  );

  final int profileId;
  final int revision;
  final String content;
  final int attempts;
  final DateTime? nextAttemptAt;

  bool dueAt(DateTime now) =>
      nextAttemptAt == null || !nextAttemptAt!.isAfter(now.toUtc());
}

/// The local outbox. Progress is always written first; a report is queued
/// in the same transaction and removed only once the server confirms it.
class OutboxRepository {
  OutboxRepository(
    this._db, {
    Clock? clock,
    this.snapshots = const SnapshotRepository(),
  }) : _clock = clock ?? DateTime.now;

  final Database _db;
  final Clock _clock;
  final SnapshotRepository snapshots;

  /// Longest wait between automatic retries after server errors.
  static const maxBackoff = Duration(hours: 1);
  static const baseBackoff = Duration(seconds: 30);

  /// Call inside the transaction that changed [profileId]'s progress.
  /// Queues a fresh report if the profile is linked to an NGO and the report
  /// differs from what is queued or already confirmed. A newer report
  /// replaces an older queued one (they are complete snapshots, so only the
  /// latest matters). Returns true when something was queued.
  Future<bool> recordChange(DatabaseExecutor txn, int profileId) async {
    final enrolment = await txn.query(
      'ngo_enrolment',
      columns: ['sync_revision', 'acked_content'],
      where: "profile_id = ? AND status IN ('pending', 'active')",
      whereArgs: [profileId],
    );
    if (enrolment.isEmpty) return false;
    final content = await snapshots.build(txn, profileId);
    final queued = await txn.query(
      'sync_outbox',
      columns: ['content'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    if (queued.isNotEmpty && queued.single['content'] == content) return false;
    if (queued.isEmpty && enrolment.single['acked_content'] == content) {
      return false;
    }
    final revision = (enrolment.single['sync_revision']! as int) + 1;
    await txn.update(
      'ngo_enrolment',
      {'sync_revision': revision},
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    if (queued.isEmpty) {
      await txn.insert('sync_outbox', {
        'profile_id': profileId,
        'revision': revision,
        'content': content,
        'created_at': isoNow(_clock),
      });
    } else {
      // Keep attempts/next_attempt_at: new content must not reset backoff.
      await txn.update(
        'sync_outbox',
        {'revision': revision, 'content': content},
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
    }
    return true;
  }

  /// [recordChange] in its own transaction (after enrolment, for example).
  Future<bool> refresh(int profileId) =>
      _db.transaction((txn) => recordChange(txn, profileId));

  Future<OutboxItem?> pending(int profileId) async {
    final rows = await _db.query(
      'sync_outbox',
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    return rows.isEmpty ? null : OutboxItem.fromRow(rows.single);
  }

  /// The server confirmed [revision] (accepted or already had it). Clears
  /// the outbox only if nothing newer was queued meanwhile.
  Future<void> acknowledge(int profileId, int revision, String content) {
    return _db.transaction((txn) async {
      await txn.delete(
        'sync_outbox',
        where: 'profile_id = ? AND revision = ?',
        whereArgs: [profileId, revision],
      );
      // The server is reachable: a newer queued report may go at once.
      await txn.update(
        'sync_outbox',
        {'attempts': 0, 'next_attempt_at': null},
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      await txn.update(
        'ngo_enrolment',
        {
          'acked_revision': revision,
          'acked_content': content,
          'last_synced_at': isoNow(_clock),
          'last_error': null,
        },
        where: 'profile_id = ? AND acked_revision < ?',
        whereArgs: [profileId, revision],
      );
      await txn.update(
        'ngo_enrolment',
        {'last_synced_at': isoNow(_clock), 'last_error': null},
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
    });
  }

  /// The server already holds a revision at least [serverRevision]: give the
  /// queued report the next number so it is accepted as newer.
  Future<void> renumberAbove(int profileId, int serverRevision) {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'ngo_enrolment',
        columns: ['sync_revision'],
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      if (rows.isEmpty) return;
      final next =
          max(rows.single['sync_revision']! as int, serverRevision) + 1;
      await txn.update(
        'ngo_enrolment',
        {'sync_revision': next},
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      await txn.update(
        'sync_outbox',
        {'revision': next},
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
    });
  }

  /// Records a failed upload. Server errors back off exponentially
  /// (30 s, 1, 2, 4 … min, at most an hour); being offline does not back
  /// off, since trying again costs nothing and only happens on app events.
  Future<void> recordFailure(int profileId, {required bool serverError}) {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'sync_outbox',
        columns: ['attempts'],
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      if (rows.isEmpty) return;
      final attempts = (rows.single['attempts']! as int) + 1;
      final wait = serverError ? backoff(attempts) : Duration.zero;
      await txn.update(
        'sync_outbox',
        {
          'attempts': attempts,
          'next_attempt_at': serverError
              ? _clock().toUtc().add(wait).toIso8601String()
              : null,
        },
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
    });
  }

  static Duration backoff(int attempts) {
    final factor = 1 << min(attempts - 1, 10);
    final wait = baseBackoff * factor;
    return wait > maxBackoff ? maxBackoff : wait;
  }
}
