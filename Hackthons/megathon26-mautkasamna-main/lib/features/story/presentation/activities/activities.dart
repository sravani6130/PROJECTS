import 'package:flutter/material.dart';

import '../../domain/story_rules.dart';
import '../../domain/story_state.dart';
import 'activity_base.dart';
import 'c1_c2_activities.dart';
import 'c3_activities.dart';
import 'c4_activities.dart';
import 'c5_activities.dart';
import 'c6_activities.dart';
import 'c7_activities.dart';
import 'sort_activity.dart';

/// Ids of every interactive beat that has a screen. A test checks that each
/// `Play` beat in the script appears here.
const activityIds = {
  'c1_budget',
  'c1_sort',
  'c2_goal',
  'c2_week1',
  'c2_week2',
  'c2_week3',
  'c2_week4',
  'c3_open',
  'c3_bank',
  'c3_pending',
  'c4_inbox',
  'c4_recover',
  'c4_rules',
  'c5_shop',
  'c5_statement',
  'c6_compare',
  'c6_fd',
  'c6_time',
  'c7_policy',
  'c7_plan',
};

/// The screen for the interactive beat [id].
Widget buildActivity(
  String id,
  StoryState s, {
  required ActivityDone onDone,
  bool busy = false,
}) {
  return switch (id) {
    'c1_budget' => BudgetActivity(s: s, onDone: onDone, busy: busy),
    'c1_sort' => SortActivity(
      s: s,
      onDone: onDone,
      busy: busy,
      intro: 'c1_sort_intro',
      leftLabel: 'kind_need',
      rightLabel: 'kind_want',
      leftIcon: Icons.favorite_rounded,
      rightIcon: Icons.star_rounded,
      cards: [
        for (final e in StoryRules.c1Items)
          if (e.need || s.has('c1_${e.id}'))
            SortCard(
              'exp_${e.id}',
              e.prop,
              left: e.need,
              why: 'c1_why_${e.id}',
            ),
        const SortCard('exp_form', 'notebook', left: true, why: 'c1_why_form'),
      ],
    ),
    'c2_goal' => GoalActivity(s: s, onDone: onDone, busy: busy),
    'c2_week1' || 'c2_week2' || 'c2_week3' || 'c2_week4' => SaveWeekActivity(
      s: s,
      onDone: onDone,
      busy: busy,
      week: int.parse(id.substring(id.length - 1)),
    ),
    'c3_open' => OpenAccountActivity(s: s, onDone: onDone, busy: busy),
    'c3_bank' => BankActivity(s: s, onDone: onDone, busy: busy),
    'c3_pending' => PendingActivity(s: s, onDone: onDone, busy: busy),
    'c4_inbox' => InboxActivity(s: s, onDone: onDone, busy: busy),
    'c4_recover' => RecoverActivity(s: s, onDone: onDone, busy: busy),
    'c4_rules' => SortActivity(
      s: s,
      onDone: onDone,
      busy: busy,
      intro: 'c4_rules_intro',
      leftLabel: 'c4_never_share',
      rightLabel: 'c4_ok_share',
      leftIcon: Icons.lock_rounded,
      rightIcon: Icons.lock_open_rounded,
      cards: const [
        SortCard('c4_card_otp', 'phone', left: true, why: 'c4_why_otp'),
        SortCard('c4_card_upiid', 'coin', left: false, why: 'c4_why_upiid'),
        SortCard('c4_card_pin', 'lock', left: true, why: 'c4_why_pin'),
        SortCard('c4_card_cvv', 'card', left: true, why: 'c4_why_cvv'),
        SortCard('c4_card_fair', 'ticket', left: false, why: 'c4_why_fair'),
      ],
    ),
    'c5_shop' => ShopActivity(s: s, onDone: onDone, busy: busy),
    'c5_statement' => StatementActivity(s: s, onDone: onDone, busy: busy),
    'c6_compare' => CompareActivity(s: s, onDone: onDone, busy: busy),
    'c6_fd' => FdActivity(s: s, onDone: onDone, busy: busy),
    'c6_time' => TimeActivity(s: s, onDone: onDone, busy: busy),
    'c7_policy' => PolicyActivity(s: s, onDone: onDone, busy: busy),
    'c7_plan' => PlanActivity(s: s, onDone: onDone, busy: busy),
    // An unknown id would be a script bug; let the player move on.
    _ => Center(
      child: FilledButton(
        onPressed: () => onDone(const {}),
        child: const Icon(Icons.arrow_forward_rounded),
      ),
    ),
  };
}
