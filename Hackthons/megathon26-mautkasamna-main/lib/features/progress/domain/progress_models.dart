enum MissionStatus { notStarted, inProgress, completed }

/// Summary row for one chapter (MISSION_PROGRESS, ids C1..C7).
class MissionProgress {
  const MissionProgress({
    required this.missionId,
    required this.status,
    required this.bestScore,
    required this.maxScore,
    required this.attemptCount,
    required this.completionCount,
    this.firstCompletedAt,
  });

  const MissionProgress.notStarted(this.missionId)
    : status = MissionStatus.notStarted,
      bestScore = 0,
      maxScore = 0,
      attemptCount = 0,
      completionCount = 0,
      firstCompletedAt = null;

  final String missionId;
  final MissionStatus status;
  final int bestScore;
  final int maxScore;
  final int attemptCount;
  final int completionCount;
  final DateTime? firstCompletedAt;

  bool get isCompleted => status == MissionStatus.completed;

  int get bestStars =>
      maxScore == 0 ? 0 : (bestScore * 3 / maxScore).round().clamp(0, 3);
}

/// Everything the home and progress screens need for one profile.
class ProgressSnapshot {
  const ProgressSnapshot({required this.missions, required this.badgeIds});

  static const empty = ProgressSnapshot(missions: {}, badgeIds: {});

  final Map<String, MissionProgress> missions;
  final Set<String> badgeIds;

  MissionProgress mission(String id) =>
      missions[id] ?? MissionProgress.notStarted(id);

  Set<String> get completedMissionIds => {
    for (final p in missions.values)
      if (p.isCompleted) p.missionId,
  };
}
