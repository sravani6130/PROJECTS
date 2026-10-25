import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/features/story/application/story_controller.dart';
import 'package:gullak/features/story/domain/story_rules.dart';
import 'package:gullak/features/story/domain/story_script.dart';
import 'package:gullak/features/story/domain/story_state.dart';
import 'package:gullak/features/story/presentation/chapter_screen.dart';

/// Plays chapters through the real UI by tapping widget keys, the way a
/// student would. [reckless] makes the risky choice wherever there is one
/// (and a deliberate mistake first), so both sides of every branch run.
class StoryDriver {
  StoryDriver(this.tester, {this.reckless = false, this.onBeat});

  final WidgetTester tester;
  final bool reckless;

  /// Called as each beat is first shown, with a label such as `c3_04_Play`
  /// (used to capture screenshots).
  final Future<void> Function(String label)? onBeat;

  Future<void> tap(String key) async {
    final finder = find.byKey(ValueKey(key));
    expect(finder, findsOneWidget, reason: 'no widget with key $key');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(ChapterScreen)));

  StoryPlay get play => container.read(storyControllerProvider)!;

  StoryState get s => play.state;

  /// Plays the open chapter to its completion screen.
  Future<void> playChapter() async {
    var guard = 0;
    while (!play.isComplete) {
      expect(guard++, lessThan(80), reason: 'chapter did not finish');
      final beat = play.beat;
      final at = s.beat;
      await onBeat?.call(
        'c${play.chapter.number}_${'$at'.padLeft(2, '0')}_${switch (beat) {
          Talk() => 'talk',
          Pick() => beat.id,
          Play() => beat.id,
          Teach() => 'teach',
          _ => 'recap',
        }}',
      );
      switch (beat) {
        case Talk():
          var taps = 0;
          while (!play.isComplete && s.beat == at) {
            expect(taps++, lessThan(20), reason: 'dialogue did not end');
            await tap('story_next');
          }
        case Pick():
          await _pick(beat);
        case Play():
          await _activity(beat.id);
        case Teach():
          await tap('story_next');
        case Recap() || null:
          await tap('finish_chapter');
      }
      if (!play.isComplete) {
        expect(s.beat, greaterThan(at), reason: 'stuck on beat $at ($beat)');
      }
    }
  }

  Future<void> _pick(Pick pick) async {
    final choice = switch (pick.id) {
      'c1_form' => !reckless && s.wallet >= 60 ? 'own' : 'advance',
      'c2_treat' => reckless ? 'join' : 'small',
      _ => reckless ? 'drop' : 'keep',
    };
    if (reckless && pick.id == 'c1_form') {
      // A choice that is explained and then offered again.
      await tap('opt_skip');
      await tap('pick_confirm');
      await tap('pick_retry');
    }
    await tap('opt_$choice');
    await tap('pick_confirm');
    expect(find.byKey(const ValueKey('pick_result')), findsOneWidget);
    await tap('story_next');
  }

  Future<void> _sort(List<bool> left) async {
    if (reckless) await tap(left.first ? 'bin_right' : 'bin_left');
    for (final isLeft in left) {
      await tap(isLeft ? 'bin_left' : 'bin_right');
    }
    await tap('activity_done');
  }

  Future<void> _activity(String id) async {
    switch (id) {
      case 'c1_budget':
        if (reckless) {
          for (final e in StoryRules.c1Items) {
            await tap('item_${e.id}');
          }
          await tap('budget_submit');
          expect(find.byKey(const ValueKey('budget_problem')), findsOneWidget);
          await tap('item_movie');
        } else {
          for (final item in ['bus', 'lunch', 'recharge', 'movie']) {
            await tap('item_$item');
          }
        }
        await tap('budget_submit');
      case 'c1_sort':
        await _sort([
          for (final e in StoryRules.c1Items)
            if (e.need || s.has('c1_${e.id}')) e.need,
          true,
        ]);
      case 'c2_goal':
        await tap('weekly_300');
        await tap(reckless ? 'goal_laptop' : 'goal_kit');
        await tap('activity_done');
      case 'c2_week1' || 'c2_week2' || 'c2_week3' || 'c2_week4':
        if (reckless) {
          for (var i = 0; i < 10; i++) {
            await tap('amount_minus');
          }
        } else {
          await tap('amount_plus');
        }
        await tap('activity_done');
      case 'c3_open':
        await tap('open_jar');
        await tap('open_gift');
        await tap('activity_done');
      case 'c3_bank':
        if (reckless) {
          await tap('act_deposit');
          await tap('amt_150');
          await tap('bank_confirm');
          expect(find.byKey(const ValueKey('bank_hint')), findsOneWidget);
        }
        await tap('act_deposit');
        await tap('amt_300');
        await tap('bank_confirm');
        await tap('act_withdraw');
        await tap('amt_200');
        await tap('bank_confirm');
        await tap('act_upi');
        await tap('amt_150');
        await tap('payee_imran');
        await tap('bank_confirm');
        if (reckless) await tap('check_0');
        await tap('check_1');
        await tap('activity_done');
      case 'c3_pending':
        await tap('pay_fee');
        if (reckless) {
          await tap('pend_again');
        } else {
          await tap('pend_history');
          await tap('pend_row');
          await tap('pend_refresh');
        }
        expect(find.byKey(const ValueKey('pending_result')), findsOneWidget);
        await tap('activity_done');
      case 'c4_inbox':
        for (final (m, clues) in const [
          ('m1', [0, 1, 2]),
          ('m2', [0, 1, 2]),
          ('m3', [1, 2, 3]),
          ('m4', [0, 1, 2]),
        ]) {
          await tap('msg_$m');
          if (reckless) {
            await tap('clue_hint');
            await tap('dec_proceed');
          } else {
            for (final i in clues) {
              await tap('seg_${m}_$i');
            }
            await tap('dec_verify');
          }
          expect(find.byKey(const ValueKey('msg_result')), findsOneWidget);
          await tap('inbox_back');
        }
        await tap('activity_done');
      case 'c4_recover':
        await tap('rec_wait');
        await tap('recover_check');
        expect(find.byKey(const ValueKey('recover_wrong')), findsOneWidget);
        await tap('rec_wait');
        for (final action in ['tell', 'bank', 'report']) {
          await tap('rec_$action');
        }
        await tap('recover_check');
        await tap('activity_done');
      case 'c4_rules':
        await _sort([true, false, true, true, false]);
      case 'c5_shop':
        if (reckless) {
          await tap('shop_nova');
          await tap('shop_choose');
          await tap('pay_credit');
        } else {
          await tap('shop_nova');
          await tap('shop_wait');
          await tap('shop_lite');
          if (s.bank >= StoryRules.litePrice) {
            await tap('shop_choose');
            await tap('pay_debit');
          } else {
            await tap('shop_wait');
          }
        }
        await tap('activity_done');
      case 'c5_statement':
        await tap(reckless ? 'stmt_q_0' : 'stmt_q_2');
        await tap('plan_0');
        await tap('plan_1');
        if (s.debt > 0) await tap('payopt_0');
        await tap('activity_done');
      case 'c6_compare':
        await tap(reckless ? 'cmp_q_1' : 'cmp_q_0');
        for (var i = 0; i < StoryRules.fdMonths; i++) {
          if (i == 2) await tap('try_fd');
          await tap('month_plus');
        }
        await tap('try_sav');
        await tap('activity_done');
      case 'c6_fd':
        final options = StoryRules.c6FdOptions(s);
        final amount = reckless
            ? options.last
            : options.lastWhere(
                (a) => s.bank - a >= StoryRules.surpriseCost,
                orElse: () => 0,
              );
        await tap('fd_$amount');
        await tap('activity_done');
      case 'c6_time':
        for (var i = 0; i < 3; i++) {
          await tap('next_month');
        }
        final options = StoryRules.c6EventOptions(
          StoryRules.c6Months(s, null).last,
        );
        final wanted = reckless ? 'break' : 'savings';
        await tap('evt_${options.contains(wanted) ? wanted : 'family'}');
        for (var i = 0; i < 3; i++) {
          await tap('next_month');
        }
        expect(find.byKey(const ValueKey('maturity_card')), findsOneWidget);
        await tap('activity_done');
      case 'c7_policy':
        for (final part in ['premium', 'limit', 'deductible', 'exclusions']) {
          await tap('pol_$part');
        }
        await tap(reckless ? 'claim_yes' : 'claim_no');
        await tap(reckless ? 'calc_0' : 'calc_1');
        await tap('activity_done');
      case 'c7_plan':
        if (reckless) {
          await tap('src_power');
          expect(find.byKey(const ValueKey('plan_warning')), findsOneWidget);
        } else {
          await tap('src_tv');
        }
        for (final source in ['fund', 'eatOut', 'uncle']) {
          await tap('src_$source');
        }
        await tap('activity_done');
      default:
        fail('no driver for activity $id');
    }
  }
}
