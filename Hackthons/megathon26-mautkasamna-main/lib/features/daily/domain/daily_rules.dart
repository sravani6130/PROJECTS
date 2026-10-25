/// Daily check-in: once a calendar day, the player drops pretend money into
/// their Gullak. Checking in on consecutive days builds a streak, and every
/// full week of streak adds a bonus. Pure Dart so it is easy to test.
abstract final class DailyRules {
  /// Pretend rupees for each daily check-in.
  static const dailyReward = 5;

  /// Extra pretend rupees on day 7, 14, 21… of a streak.
  static const weeklyBonus = 20;
  static const week = 7;

  /// Streak lengths that get their own message in the inbox.
  static const milestones = {3, 7, 14, 30, 50, 100};

  /// The local calendar day of [time] as `YYYY-MM-DD`.
  static String dayKey(DateTime time) {
    final d = time.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime _parse(String day) => DateTime.utc(
    int.parse(day.substring(0, 4)),
    int.parse(day.substring(5, 7)),
    int.parse(day.substring(8, 10)),
  );

  /// Whole calendar days from [from] to [to] (both `YYYY-MM-DD`).
  static int daysBetween(String from, String to) =>
      _parse(to).difference(_parse(from)).inDays;

  /// The streak after checking in on [today], given the last check-in.
  static int nextStreak({
    String? lastDay,
    int lastStreak = 0,
    required String today,
  }) {
    if (lastDay == null) return 1;
    return daysBetween(lastDay, today) == 1 ? lastStreak + 1 : 1;
  }

  /// The bonus earned on a day that brings the streak to [streak].
  static int bonusFor(int streak) =>
      streak > 0 && streak % week == 0 ? weeklyBonus : 0;

  /// The streak still alive on [today]: kept if the last check-in was today
  /// or yesterday, otherwise broken.
  static int liveStreak({
    String? lastDay,
    int lastStreak = 0,
    required String today,
  }) {
    if (lastDay == null) return 0;
    final gap = daysBetween(lastDay, today);
    return gap <= 1 ? lastStreak : 0;
  }
}

/// Where the active player's daily check-in stands today.
class DailyStatus {
  const DailyStatus({
    required this.today,
    required this.checkedInToday,
    required this.streak,
    required this.total,
    required this.days,
  });

  static const empty = DailyStatus(
    today: '',
    checkedInToday: false,
    streak: 0,
    total: 0,
    days: 0,
  );

  final String today;
  final bool checkedInToday;

  /// Consecutive days, counting today if already checked in.
  final int streak;

  /// Every pretend rupee collected from check-ins.
  final int total;

  /// How many days the player has ever checked in.
  final int days;

  /// What a check-in today would give.
  int get nextReward =>
      DailyRules.dailyReward +
      DailyRules.bonusFor(checkedInToday ? streak : streak + 1);

  /// Days of the current week already checked in (0–7), for the bonus dots.
  int get weekProgress {
    final r = streak % DailyRules.week;
    // A finished week shows full on its last day; the next day starts afresh.
    if (streak == 0 || (r == 0 && !checkedInToday)) return 0;
    return r == 0 ? DailyRules.week : r;
  }
}

/// The result of one check-in.
class CheckIn {
  const CheckIn({
    required this.reward,
    required this.bonus,
    required this.streak,
  });

  final int reward;
  final int bonus;
  final int streak;

  int get total => reward + bonus;
}
