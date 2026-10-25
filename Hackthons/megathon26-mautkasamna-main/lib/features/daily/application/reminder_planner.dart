import '../../../core/localization/app_strings.dart';
import '../../../core/notifications/reminders.dart';
import '../domain/daily_rules.dart';

/// Plans the next few daily reminders at [hour], worded for how things will
/// stand on each day if the player doesn't open the app before then. They
/// are re-planned every time something changes, so a player who checks in
/// never gets a stale message. After [days] quiet days the reminders stop
/// rather than nag.
List<PlannedReminder> planReminders({
  required DateTime now,
  required int hour,
  required DailyStatus status,
  required AppStrings t,
  required int chaptersDone,
  required int chapterCount,
  String? nextChapterTitle,
  int days = 3,
}) {
  final local = now.toLocal();
  final plans = <PlannedReminder>[];
  for (var d = 0; d < days; d++) {
    final at = DateTime(local.year, local.month, local.day + d, hour);
    if (!at.isAfter(local)) continue;
    if (d == 0 && status.checkedInToday) continue;

    // Days since the last check-in when this reminder fires. The streak
    // survives only if that check-in was yesterday.
    final gap = status.streak == 0 ? null : d + (status.checkedInToday ? 0 : 1);
    final alive = gap == 1;
    final reward =
        DailyRules.dailyReward +
        DailyRules.bonusFor(alive ? status.streak + 1 : 1);

    final body = StringBuffer(
      alive
          ? t('rem_body_streak', {'reward': reward, 'streak': status.streak})
          : t(d >= 2 ? 'rem_body_miss' : 'rem_body', {'reward': reward}),
    );
    if (nextChapterTitle != null) {
      body
        ..write(' ')
        ..write(
          t('rem_chapter', {
            'done': chaptersDone,
            'total': chapterCount,
            'title': nextChapterTitle,
          }),
        );
    }
    plans.add(
      PlannedReminder(
        id: LocalReminders.idRange.first + d,
        at: at,
        title: alive
            ? t('rem_title_streak', {'streak': status.streak})
            : t('rem_title'),
        body: body.toString(),
      ),
    );
  }
  return plans;
}
