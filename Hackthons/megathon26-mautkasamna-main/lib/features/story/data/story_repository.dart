import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/utils/ids.dart';
import '../domain/story_rules.dart';
import '../domain/story_state.dart';

/// Thrown when the saved story changed since it was read (for example a
/// second tap already saved the same step). Nothing was written.
class StaleStoryException implements Exception {}

/// Computes badge ids for a set of completed chapter ids. Supplied by the
/// domain layer so the repository holds no reward rules.
typedef BadgeEvaluator = Set<String> Function(Set<String> completedIds);

/// Runs inside the transaction that changed a profile's progress (used to
/// queue an NGO progress report atomically with the change).
typedef ProgressChangeHook = Future<void> Function(
  DatabaseExecutor txn,
  int profileId,
);

/// A profile's saved story as read from the database.
class StorySave {
  const StorySave({
    required this.state,
    required this.revision,
    required this.starts,
  });

  final StoryState state;
  final int revision;

  /// State at the start of each chapter reached so far.
  final Map<int, StoryState> starts;
}

/// STORY_SAVE, plus chapter completion in MISSION_PROGRESS and BADGE_AWARD.
class StoryRepository {
  StoryRepository(this._db, {Clock? clock, this.onProgressChanged})
    : _clock = clock ?? DateTime.now;

  final Database _db;
  final Clock _clock;
  final ProgressChangeHook? onProgressChanged;

  String get _now => isoNow(_clock);

  /// Loads the story for [profileId], creating a fresh one on first use.
  Future<StorySave> load(int profileId) {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        'story_save',
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      if (rows.isNotEmpty) return _fromRow(rows.single);
      final fresh = StoryRules.newStory();
      await txn.insert('story_save', {
        'profile_id': profileId,
        'state_json': fresh.encode(),
        'chapter_starts': jsonEncode({'1': fresh.toJson()}),
        'updated_at': _now,
      });
      return StorySave(state: fresh, revision: 0, starts: {1: fresh});
    });
  }

  /// Saves a checkpoint. Returns the new revision.
  Future<int> saveStep(int profileId, StoryState state, int revision) {
    return _db.transaction((txn) async {
      final next = await _write(txn, profileId, state, revision);
      await onProgressChanged?.call(txn, profileId);
      return next;
    });
  }

  /// Records a finished chapter. In the story run ([next] given) the saved
  /// state moves to the next chapter in the same transaction; a practice
  /// replay ([next] null) only updates stars and play counts.
  ///
  /// Returns the new revision and the ids of badges newly awarded.
  Future<({int revision, Set<String> badges})> completeChapter({
    required int profileId,
    required int chapter,
    required int stars,
    required int revision,
    StoryState? next,
    BadgeEvaluator? badgeEvaluator,
  }) {
    return _db.transaction((txn) async {
      final now = _now;
      var newRevision = revision;
      if (next != null) {
        final row = await txn.query(
          'story_save',
          columns: ['chapter_starts'],
          where: 'profile_id = ?',
          whereArgs: [profileId],
        );
        final starts = row.isEmpty
            ? <String, Object?>{}
            : _decodeMap(row.single['chapter_starts']);
        if (!next.finished) starts['${next.chapter}'] = next.toJson();
        newRevision = await _write(
          txn,
          profileId,
          next,
          revision,
          starts: starts,
        );
      }
      await txn.rawInsert(
        '''
        INSERT INTO mission_progress
          (profile_id, mission_id, status, best_score, max_score,
           attempt_count, completion_count, first_completed_at, last_played_at)
        VALUES (?, ?, 'completed', ?, 3, 1, 1, ?, ?)
        ON CONFLICT (profile_id, mission_id) DO UPDATE SET
          status             = 'completed',
          best_score         = MAX(best_score, excluded.best_score),
          attempt_count      = attempt_count + 1,
          completion_count   = completion_count + 1,
          first_completed_at = COALESCE(first_completed_at, excluded.first_completed_at),
          last_played_at     = excluded.last_played_at
        ''',
        [profileId, 'C$chapter', stars.clamp(0, 3), now, now],
      );

      if (badgeEvaluator == null) {
        await onProgressChanged?.call(txn, profileId);
        return (revision: newRevision, badges: const <String>{});
      }
      final completed = await txn.query(
        'mission_progress',
        columns: ['mission_id'],
        where: "profile_id = ? AND status = 'completed'",
        whereArgs: [profileId],
      );
      final earned = badgeEvaluator({
        for (final row in completed) row['mission_id']! as String,
      });
      final existing = await txn.query(
        'badge_award',
        columns: ['badge_id'],
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      final newlyAwarded = earned.difference({
        for (final row in existing) row['badge_id']! as String,
      });
      for (final badgeId in newlyAwarded) {
        // INSERT OR IGNORE keeps awards idempotent even under a race.
        await txn.rawInsert(
          'INSERT OR IGNORE INTO badge_award (profile_id, badge_id, awarded_at) '
          'VALUES (?, ?, ?)',
          [profileId, badgeId, now],
        );
      }
      await onProgressChanged?.call(txn, profileId);
      return (revision: newRevision, badges: newlyAwarded);
    });
  }

  Future<int> _write(
    Transaction txn,
    int profileId,
    StoryState state,
    int revision, {
    Map<String, Object?>? starts,
  }) async {
    final changed = await txn.update(
      'story_save',
      {
        'state_json': state.encode(),
        'chapter_starts': ?(starts == null ? null : jsonEncode(starts)),
        'revision': revision + 1,
        'updated_at': _now,
      },
      where: 'profile_id = ? AND revision = ?',
      whereArgs: [profileId, revision],
    );
    if (changed != 1) throw StaleStoryException();
    return revision + 1;
  }

  StorySave _fromRow(Map<String, Object?> row) {
    final starts = _decodeMap(row['chapter_starts']);
    return StorySave(
      state: StoryState.decode(row['state_json']! as String),
      revision: row['revision']! as int,
      starts: {
        for (final e in starts.entries)
          if (int.tryParse(e.key) != null && e.value is Map)
            int.parse(e.key): StoryState.fromJson(
              (e.value! as Map).cast<String, Object?>(),
            ),
      },
    );
  }

  static Map<String, Object?> _decodeMap(Object? raw) {
    try {
      final json = jsonDecode(raw as String? ?? '{}');
      if (json is Map) return json.cast<String, Object?>();
    } on FormatException {
      // Treated as empty: practice replays fall back to a fresh start.
    }
    return {};
  }
}
