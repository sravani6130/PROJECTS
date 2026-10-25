import '../../content/domain/content_models.dart';

/// Badge ids earned for a set of completed missions. Badges are private
/// progress markers; there is no ranking or comparison.
Set<String> earnedBadgeIds(
  List<BadgeDefinition> badges,
  Set<String> completedMissionIds,
) {
  return {
    for (final badge in badges)
      if (_isEarned(badge, completedMissionIds)) badge.id,
  };
}

bool _isEarned(BadgeDefinition badge, Set<String> completed) =>
    switch (badge.ruleType) {
      BadgeRuleType.completeAny => badge.missionIds.any(completed.contains),
      BadgeRuleType.completeAll => badge.missionIds.every(completed.contains),
    };
