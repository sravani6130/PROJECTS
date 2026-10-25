import 'package:sqflite/sqflite.dart';

import '../../story/data/story_repository.dart' show ProgressChangeHook;
import '../domain/progress_models.dart';

/// Read model for the home and progress screens, plus per-profile reset.
class ProgressRepository {
  ProgressRepository(this._db, {this.onProgressChanged});

  final Database _db;
  final ProgressChangeHook? onProgressChanged;

  Future<ProgressSnapshot> loadSnapshot(int profileId) async {
    final missionRows = await _db.query(
      'mission_progress',
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    final badgeRows = await _db.query(
      'badge_award',
      columns: ['badge_id'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'awarded_at',
    );
    return ProgressSnapshot(
      missions: {
        for (final row in missionRows)
          row['mission_id']! as String: _missionFromRow(row),
      },
      badgeIds: {for (final row in badgeRows) row['badge_id']! as String},
    );
  }

  /// Erases one profile's learning history but keeps the profile itself.
  /// Other profiles on the device are unaffected.
  Future<void> resetProfileProgress(int profileId) {
    return _db.transaction((txn) async {
      for (final table in const [
        'story_save',
        'attempt', // decisions cascade
        'mission_progress',
        'study_progress',
        'assessment_result',
        'badge_award',
        'daily_checkin',
        'inbox',
      ]) {
        await txn.delete(
          table,
          where: 'profile_id = ?',
          whereArgs: [profileId],
        );
      }
      // A linked NGO sees the reset too (as a newer, emptier report).
      await onProgressChanged?.call(txn, profileId);
    });
  }

  MissionProgress _missionFromRow(Map<String, Object?> row) {
    final completedAt = row['first_completed_at'] as String?;
    return MissionProgress(
      missionId: row['mission_id']! as String,
      status: row['status'] == 'completed'
          ? MissionStatus.completed
          : MissionStatus.inProgress,
      bestScore: row['best_score']! as int,
      maxScore: row['max_score']! as int,
      attemptCount: row['attempt_count']! as int,
      completionCount: row['completion_count']! as int,
      firstCompletedAt: completedAt == null
          ? null
          : DateTime.parse(completedAt),
    );
  }
}
