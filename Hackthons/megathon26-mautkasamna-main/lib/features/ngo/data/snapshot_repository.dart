import 'package:sqflite/sqflite.dart';

import '../../story/domain/story_state.dart';
import '../domain/progress_report.dart';

/// Reads the profile's saved progress (STORY_SAVE, MISSION_PROGRESS,
/// BADGE_AWARD) and turns it into report content. Runs inside the caller's
/// transaction so the snapshot matches what was just written.
class SnapshotRepository {
  const SnapshotRepository();

  Future<String> build(DatabaseExecutor db, int profileId) async {
    final save = await db.query(
      'story_save',
      columns: ['state_json', 'updated_at'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    final missions = await db.query(
      'mission_progress',
      where: "profile_id = ? AND status = 'completed' AND mission_id LIKE 'C%'",
      whereArgs: [profileId],
    );
    final badges = await db.query(
      'badge_award',
      columns: ['badge_id'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    final story = save.isEmpty
        ? const StoryState()
        : StoryState.decode(save.single['state_json']! as String);
    final times =
        [
              if (save.isNotEmpty) save.single['updated_at'] as String?,
              for (final m in missions) m['last_played_at'] as String?,
            ]
            .map((t) => DateTime.tryParse(t ?? ''))
            .whereType<DateTime>()
            .toList()
          ..sort();
    return encodeReportContent(
      buildReportContent(
        story: story,
        chapters: [
          for (final m in missions)
            if (RegExp(r'^C[1-7]$').hasMatch(m['mission_id']! as String))
              ChapterSummary(
                id: m['mission_id']! as String,
                bestStars: m['best_score']! as int,
                plays: m['attempt_count']! as int,
                firstCompletedAt: m['first_completed_at'] as String?,
              ),
        ],
        badgeIds: [for (final b in badges) b['badge_id']! as String],
        lastActivity: times.isEmpty ? null : times.last,
      ),
    );
  }
}
