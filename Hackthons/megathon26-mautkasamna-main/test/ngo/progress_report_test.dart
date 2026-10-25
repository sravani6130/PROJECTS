import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/features/ngo/domain/progress_report.dart';
import 'package:gullak/features/story/domain/story_rules.dart';
import 'package:gullak/features/story/domain/story_state.dart';

void main() {
  StoryState afterChapterOne() {
    var s = StoryRules.newStory();
    s = StoryRules.apply(s, 'c1_budget', {
      'items': ['bus', 'lunch', 'recharge', 'movie'],
    });
    s = StoryRules.apply(s, 'c1_form', {'option': 'advance'});
    return StoryRules.finishChapter(s);
  }

  test('report holds progress, never balances or personal data', () {
    final s = afterChapterOne();
    final content = buildReportContent(
      story: s,
      chapters: const [
        ChapterSummary(
          id: 'C1',
          bestStars: 3,
          plays: 2,
          firstCompletedAt: '2026-10-10T10:00:00.000Z',
        ),
      ],
      badgeIds: const ['budget_planner', 'budget_planner'],
      lastActivity: DateTime.utc(2026, 10, 11, 9, 47, 12),
    );
    expect(content['story'], {'current_chapter': 2, 'finished': false});
    expect(content['badges'], ['budget_planner']);
    // Rounded to the hour.
    expect(content['last_activity_at'], '2026-10-11T09:00:00.000Z');
    expect(content['indicators'], {'c1_surprise_cost': 'advance'});
    final text = jsonEncode(content);
    for (final secret in [
      'wallet',
      'jar',
      'bank',
      'debt',
      'txns',
      'nickname',
    ]) {
      expect(text, isNot(contains(secret)), reason: secret);
    }
  });

  test('indicators only for finished chapters', () {
    // Mid chapter 1: flags exist but the chapter is not done.
    final mid = StoryRules.apply(StoryRules.newStory(), 'c1_budget', {
      'items': ['bus', 'lunch', 'recharge'],
    }).withFlag('c1_form', 'own');
    expect(learningIndicators(mid), isEmpty);
  });

  test('scam and credit indicators are categories, not amounts', () {
    final s = const StoryState(
      chapter: 6,
      done: {1: 3, 2: 2, 3: 2, 4: 1, 5: 2},
      goalId: 'laptop',
      flags: {
        'c3_pending': 'double',
        'c5_item': 'nova',
        'c5_method': 'credit',
        'c5_pay': 'min',
      },
      nums: {'c2_w1': 50, 'c2_w3': 100, 'c4_safe': 3, 'c4_unsafe': 1},
      hints: 2,
    );
    expect(learningIndicators(s), {
      'c2_goal': 'laptop',
      'c2_weeks_saved': 2,
      'c3_pending_payment': 'paid_twice',
      'c4_scams_handled_safely': 3,
      'c4_scams_followed': 1,
      'c4_hints_used': 2,
      'c5_payment_method': 'credit',
      'c5_credit_repayment': 'minimum',
    });
  });

  test('payload adds identity, revision and schema version', () {
    final payload = reportPayload(
      content: encodeReportContent({'app_version': gullakAppVersion}),
      studentId: 'STU-AAAA-BBBB',
      revision: 7,
      generatedAt: DateTime.utc(2026, 10, 11),
    );
    expect(payload['schema_version'], 1);
    expect(payload['student_id'], 'STU-AAAA-BBBB');
    expect(payload['revision'], 7);
    expect(payload['app_version'], gullakAppVersion);
  });
}
