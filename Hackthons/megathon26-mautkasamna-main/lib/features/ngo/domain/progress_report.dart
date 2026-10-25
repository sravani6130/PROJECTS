import 'dart:convert';

import '../../story/domain/story_state.dart';

/// Version of the JSON report the server accepts (`schema_version`).
const progressReportSchema = 1;

/// App version sent with registrations and reports (keep in step with
/// `pubspec.yaml`).
const gullakAppVersion = '1.0.0';

/// One chapter's summary row (MISSION_PROGRESS) as reported to the NGO.
class ChapterSummary {
  const ChapterSummary({
    required this.id,
    required this.bestStars,
    required this.plays,
    this.firstCompletedAt,
  });

  final String id;
  final int bestStars;
  final int plays;
  final String? firstCompletedAt;
}

/// What an NGO learns about a student's progress: chapter completion and
/// stars, badges, where they are in the story, and the outcome of key
/// decisions in chapters they have finished. Never money balances, the
/// nickname, the diary of transactions or anything about the device.
///
/// Returns the report body without `student_id`, `revision` and
/// `generated_at`, which are added at upload time. Keys are in a fixed
/// order, so the encoded form can be compared to detect "nothing changed".
Map<String, Object?> buildReportContent({
  required StoryState story,
  required List<ChapterSummary> chapters,
  required Iterable<String> badgeIds,
  DateTime? lastActivity,
}) {
  final sorted = [...chapters]..sort((a, b) => a.id.compareTo(b.id));
  return {
    'last_activity_at': lastActivity == null ? null : _hour(lastActivity),
    'app_version': gullakAppVersion,
    'story': {
      'current_chapter': story.chapter.clamp(1, StoryState.chapterCount + 1),
      'finished': story.finished,
    },
    'chapters': [
      for (final c in sorted)
        {
          'id': c.id,
          'completed': true,
          'best_stars': c.bestStars.clamp(1, 3),
          'plays': c.plays,
          'first_completed_at': c.firstCompletedAt,
        },
    ],
    'badges': [...badgeIds.toSet()]..sort(),
    'indicators': learningIndicators(story),
  };
}

String encodeReportContent(Map<String, Object?> content) => jsonEncode(content);

/// Rounded down to the hour: enough to tell who played recently without
/// reporting exactly when a student was on the phone.
String _hour(DateTime t) {
  final u = t.toUtc();
  return DateTime.utc(u.year, u.month, u.day, u.hour).toIso8601String();
}

/// Outcomes of the story's teaching decisions, taken only from chapters the
/// student finished in the story run (practice replays never change the
/// saved story). Each value is a category or small count, never an amount.
Map<String, Object> learningIndicators(StoryState s) {
  bool done(int chapter) => s.done.containsKey(chapter);
  final out = <String, Object>{};
  if (done(1)) {
    final form = s.flag('c1_form');
    if (form != null) {
      out['c1_surprise_cost'] = form == 'own' ? 'own_money' : 'advance';
    }
  }
  if (done(2)) {
    if (s.goalId != null) out['c2_goal'] = s.goalId!;
    out['c2_weeks_saved'] = [
      for (var w = 1; w <= 4; w++)
        if (s.n('c2_w$w') > 0) w,
    ].length;
  }
  if (done(3)) {
    final pending = switch (s.flag('c3_pending')) {
      'verify' => 'verified',
      'double' => 'paid_twice',
      'cash' => 'paid_cash',
      _ => null,
    };
    if (pending != null) out['c3_pending_payment'] = pending;
  }
  if (done(4)) {
    out['c4_scams_handled_safely'] = s.n('c4_safe').clamp(0, 4);
    out['c4_scams_followed'] = s.n('c4_unsafe').clamp(0, 4);
    out['c4_hints_used'] = s.hints.clamp(0, 1000);
  }
  if (done(5)) {
    final method = s.flag('c5_method');
    final payment = s.flag('c5_item') == 'wait'
        ? 'waited'
        : (const {'debit', 'cash', 'credit'}.contains(method) ? method : null);
    if (payment != null) out['c5_payment_method'] = payment;
    final repay = switch (s.flag('c5_pay')) {
      'full' => 'full',
      'more' => 'more_than_minimum',
      'min' => 'minimum',
      _ => null,
    };
    if (repay != null) out['c5_credit_repayment'] = repay;
  }
  if (done(6)) {
    out['c6_fixed_deposit'] = s.n('c6_fd') > 0;
    final source = switch (s.flag('c6_event')) {
      'savings' => 'savings',
      'break' => 'broke_deposit',
      'family' => 'borrowed_family',
      _ => null,
    };
    if (source != null) out['c6_emergency_source'] = source;
  }
  if (done(7)) {
    out['c7_claimed_excluded_cost'] = s.flag('c7_claim') == 'tried';
    final policy = s.flag('c7_policy');
    if (const {'keep', 'addon', 'drop'}.contains(policy)) {
      out['c7_policy_choice'] = policy!;
    }
    out['c7_used_emergency_fund'] = s.has('c7_fund');
  }
  return out;
}

/// The full body POSTed to `/api/v1/progress`.
Map<String, Object?> reportPayload({
  required String content,
  required String studentId,
  required int revision,
  required DateTime generatedAt,
}) => {
  'schema_version': progressReportSchema,
  'student_id': studentId,
  'revision': revision,
  'generated_at': generatedAt.toUtc().toIso8601String(),
  ...(jsonDecode(content) as Map).cast<String, Object?>(),
};
