import 'dart:math';

import 'story_state.dart';

/// Thrown when a screen submits something the simulation does not allow
/// (for example spending more than the wallet holds). Nothing is changed.
class StoryRuleError implements Exception {
  StoryRuleError(this.message);

  final String message;

  @override
  String toString() => 'StoryRuleError: $message';
}

/// Something Asha can pay for. [prop] names the illustration.
class Expense {
  const Expense(this.id, this.cost, this.prop, {this.need = false});

  final String id;
  final int cost;
  final String prop;
  final bool need;
}

class SavingsGoal {
  const SavingsGoal(this.id, this.target, this.prop);

  final String id;
  final int target;
  final String prop;
}

/// Result of repaying borrowed money at a fixed amount each month.
class RepayPlan {
  const RepayPlan({
    required this.months,
    required this.totalInterest,
    required this.totalPaid,
    required this.endless,
  });

  final int months;
  final int totalInterest;
  final int totalPaid;

  /// True when the payment never clears the debt within ten years.
  final bool endless;
}

/// Every number and state change in The Money Diaries. Pure Dart and
/// deterministic: all amounts are fictional whole rupees.
abstract final class StoryRules {
  // ---- Chapter 1: the first ₹1,000 ---------------------------------------

  static const pocketMoney = 1000;
  static const c1Items = [
    Expense('bus', 200, 'bus', need: true),
    Expense('lunch', 250, 'tiffin', need: true),
    Expense('recharge', 150, 'phone', need: true),
    Expense('movie', 200, 'ticket'),
    Expense('headphones', 350, 'headphones'),
    Expense('chaat', 50, 'samosa'),
  ];
  static const c1FormCost = 60;

  static Expense c1Item(String id) => c1Items.firstWhere(
    (e) => e.id == id,
    orElse: () => throw StoryRuleError('unknown expense $id'),
  );

  static int c1Total(Iterable<String> ids) =>
      ids.toSet().fold(0, (sum, id) => sum + c1Item(id).cost);

  static List<String> c1MissingNeeds(Iterable<String> ids) => [
    for (final e in c1Items)
      if (e.need && !ids.contains(e.id)) e.id,
  ];

  // ---- Chapter 2: the laptop dream ---------------------------------------

  static const giftAmount = 100;
  static const weeklyMoney = 300;
  static const labRecordCost = 80;
  static const goals = [
    SavingsGoal('kit', 1000, 'notebook'),
    SavingsGoal('course', 1500, 'headphones'),
    SavingsGoal('laptop', 3000, 'laptop'),
  ];

  /// Money Asha can decide about in [week] (1–4) after fixed costs.
  static int c2Income(StoryState s, int week) {
    var money = weeklyMoney;
    if (week == 1) money -= s.n('c1_advance');
    if (week == 2) {
      money -= switch (s.flag('c2_treat')) {
        'join' => 100,
        'small' => 30,
        _ => 0,
      };
    }
    if (week == 3) money -= labRecordCost;
    return money;
  }

  /// Weeks needed to reach [target] from [saved] at [weekly]; null when
  /// nothing is being saved.
  static int? weeksToGoal(int target, int saved, int weekly) {
    if (saved >= target) return 0;
    if (weekly <= 0) return null;
    return ((target - saved) / weekly).ceil();
  }

  // ---- Chapter 3: digital money ------------------------------------------

  static const openingGift = 200;
  static const depositAmount = 300;
  static const withdrawAmount = 200;
  static const upiAmount = 150;
  static const fairFee = 100;

  // ---- Chapter 4: suspicious messages ------------------------------------

  /// Fictional amount at risk when the player follows each message.
  static const scamAmounts = {'m1': 200, 'm2': 300, 'm3': 499, 'm4': 500};

  /// Part of each loss that reporting does not bring back.
  static const scamUnrecovered = 50;

  // ---- Chapter 5: buy now or wait ----------------------------------------

  static const litePrice = 1200;
  static const novaPrice = 3000;

  /// Fictional interest on unpaid store credit, per month.
  static const creditRatePercent = 3;

  static int priceOf(String item) => switch (item) {
    'lite' => litePrice,
    'nova' => novaPrice,
    _ => throw StoryRuleError('unknown item $item'),
  };

  static bool c5CanPay(StoryState s, String item, String method) {
    if (item == 'wait') return method == 'none';
    final price = priceOf(item);
    return switch (method) {
      'debit' => s.bank >= price,
      'cash' => s.wallet >= price,
      'credit' => true,
      _ => false,
    };
  }

  /// Ten per cent of what is owed, rounded up to ₹10, at least ₹100.
  static int minPayment(int debt) {
    final tenth = (debt + 9) ~/ 10;
    return min(debt, max(100, ((tenth + 9) ~/ 10) * 10));
  }

  static int monthlyInterest(int debt) =>
      (debt * creditRatePercent + 50) ~/ 100;

  /// First-statement payment choices Asha can actually afford.
  static List<int> c5PayOptions(StoryState s) {
    if (s.debt == 0) return const [];
    if (s.bank == 0) return const [0];
    final lowest = min(minPayment(s.debt), s.bank);
    final half = min(s.bank, (s.debt ~/ 200) * 100);
    return ({
      lowest,
      if (half > lowest) half,
      if (s.bank >= s.debt) s.debt,
    }.toList()..sort());
  }

  /// Paying [monthly] each month. Nothing is charged on the first statement;
  /// after that the unpaid balance grows by [creditRatePercent] a month.
  static RepayPlan repaySchedule(int principal, int monthly) {
    var remaining = principal;
    var interest = 0;
    var paid = 0;
    var months = 0;
    while (remaining > 0 && months < 120) {
      if (months > 0) {
        final charge = monthlyInterest(remaining);
        remaining += charge;
        interest += charge;
      }
      final pay = min(monthly, remaining);
      if (pay <= 0) break;
      remaining -= pay;
      paid += pay;
      months++;
    }
    return RepayPlan(
      months: months,
      totalInterest: interest,
      totalPaid: paid,
      endless: remaining > 0,
    );
  }

  // ---- Chapter 6: make your money work -----------------------------------

  static const savingsRatePercent = 3;
  static const fdRatePercent = 6;
  static const fdMonths = 6;
  static const surpriseCost = 300;
  static const exampleAmount = 2000;

  /// Simple interest for [months] at [ratePercent] a year, in whole rupees.
  static int simpleInterest(int amount, int ratePercent, int months) =>
      amount * ratePercent * months ~/ 1200;

  static List<int> c6FdOptions(StoryState s) => [
    for (final a in const [0, 500, 1000, 1500, 2000])
      if (a <= s.bank) a,
  ];

  /// One simulated month: pocket-money savings arrive, then any store
  /// credit charges interest and takes the planned repayment.
  static StoryState monthTick(StoryState s) {
    var next = s;
    if (s.monthlySave > 0) {
      next = _move(next, 'bank', 'txn_monthly_save', s.monthlySave);
    }
    if (next.debt > 0) {
      final charge = monthlyInterest(next.debt);
      if (charge > 0) {
        next = _move(
          next,
          'credit',
          'txn_interest',
          charge,
        ).copyWith(interestPaid: next.interestPaid + charge);
      }
      final pay = [next.debt, next.creditPlan, next.bank].reduce(min);
      if (pay > 0) {
        next = _move(next, 'bank', 'txn_credit_pay', -pay);
        next = _move(next, 'credit', 'txn_credit_pay', -pay);
      }
    }
    return next;
  }

  /// Ways to meet the month-three surprise cost from [atMonth3].
  static List<String> c6EventOptions(StoryState atMonth3) => [
    if (atMonth3.bank >= surpriseCost) 'savings',
    if (atMonth3.fd > 0) 'break',
    'family',
  ];

  static StoryState _c6Event(StoryState s, String event) {
    if (!c6EventOptions(s).contains(event)) {
      throw StoryRuleError('event choice $event is not available');
    }
    switch (event) {
      case 'savings':
        return _move(s, 'bank', 'txn_surprise', -surpriseCost);
      case 'break':
        final principal = s.fd;
        var next = _move(s, 'fd', 'txn_fd_break', -principal);
        next = _move(next, 'bank', 'txn_fd_break', principal);
        next = _move(next, 'bank', 'txn_surprise', -surpriseCost);
        return next.withFlag('c6_broke', '1');
      default:
        return s.withNum('c6_owe', surpriseCost);
    }
  }

  /// State after each of the six months. With [event] null the list stops
  /// at month three, just before the surprise cost is handled.
  static List<StoryState> c6Months(StoryState s, String? event) {
    final months = <StoryState>[];
    var current = s;
    for (var m = 1; m <= fdMonths; m++) {
      current = monthTick(current);
      if (m == 3) {
        if (event == null) return [...months, current];
        current = _c6Event(current, event);
      }
      months.add(current);
    }
    return months;
  }

  // ---- Chapter 7: when plans change --------------------------------------

  static const clinicBill = 1000;
  static const familyFund = 400;
  static const eatOutCut = 300;
  static const tvCut = 200;
  static const uncleLoan = 300;
  static const ashaMax = 500;
  static const premium = 150;
  static const coverLimit = 20000;
  static const deductible = 500;
  static const hospitalExample = 6000;

  /// What the fictional policy pays: nothing for clinic visits, and for a
  /// hospital stay the bill above the deductible, up to the cover limit.
  static int policyPays(int bill, {required bool hospitalStay}) =>
      hospitalStay ? min(coverLimit, max(0, bill - deductible)) : 0;

  static int c7AshaMax(StoryState s) => min(ashaMax, (s.bank ~/ 100) * 100);

  static int c7PlanTotal({
    required bool fund,
    required bool eatOut,
    required bool tv,
    required bool uncle,
    required int asha,
  }) =>
      (fund ? familyFund : 0) +
      (eatOut ? eatOutCut : 0) +
      (tv ? tvCut : 0) +
      (uncle ? uncleLoan : 0) +
      asha;

  // ---- Chapter flow ------------------------------------------------------

  static StoryState newStory() => startChapter(const StoryState(), 1);

  /// Enters [chapter]: resets the chapter score and applies money that
  /// arrives as the chapter opens.
  static StoryState startChapter(StoryState s, int chapter) {
    final next = s.copyWith(chapter: chapter, beat: 0, score: 0, maxScore: 0);
    return switch (chapter) {
      1 => _move(next, 'wallet', 'txn_pocket', pocketMoney),
      2 => _move(next, 'jar', 'txn_gift', giftAmount),
      3 => _move(next, 'wallet', 'txn_pocket', weeklyMoney),
      _ => next,
    };
  }

  /// Closes the current chapter, records its stars and opens the next one.
  static StoryState finishChapter(StoryState s) {
    var next = s;
    if (s.chapter == 1 && s.wallet > 0) {
      final left = s.wallet;
      next = _move(next, 'wallet', 'txn_to_jar', -left);
      next = _move(next, 'jar', 'txn_to_jar', left);
    }
    next = next.copyWith(done: {...next.done, s.chapter: s.stars});
    return s.chapter >= StoryState.chapterCount
        ? next.copyWith(chapter: StoryState.chapterCount + 1, beat: 0)
        : startChapter(next, s.chapter + 1);
  }

  /// Applies the outcome of the interactive beat [id]. [r] is what the
  /// screen reports; everything financial is recomputed and checked here.
  static StoryState apply(StoryState s, String id, Map<String, Object?> r) {
    int i(String key) => r[key] is int ? r[key]! as int : 0;
    bool b(String key) => r[key] == true;
    String str(String key) => r[key] is String ? r[key]! as String : '';

    switch (id) {
      case 'c1_budget':
        final items = [
          if (r['items'] is List)
            for (final x in r['items']! as List)
              if (x is String) x,
        ];
        final total = c1Total(items);
        if (total > s.wallet) throw StoryRuleError('over budget');
        if (c1MissingNeeds(items).isNotEmpty) {
          throw StoryRuleError('needs are not covered');
        }
        var next = s;
        for (final e in c1Items) {
          if (!items.contains(e.id)) continue;
          next = _move(next, 'wallet', 'txn_${e.id}', -e.cost);
          if (!e.need) next = next.withFlag('c1_${e.id}', '1');
        }
        return next
            .withNum('c1_spent', total)
            .withNum('c1_left', next.wallet)
            .scored(i('tries') == 0 ? 2 : 1, 2);

      case 'c1_form':
        switch (str('option')) {
          case 'own':
            return _move(
              s,
              'wallet',
              'txn_form',
              -c1FormCost,
            ).withFlag('c1_form', 'own').scored(1, 1);
          case 'advance':
            return s
                .withFlag('c1_form', 'advance')
                .withNum('c1_advance', c1FormCost)
                .scored(s.wallet >= c1FormCost ? 0 : 1, 1);
        }
        throw StoryRuleError('unknown option');

      case 'c1_sort' || 'c4_rules':
        return s.scored(i('mistakes') == 0 ? 1 : 0, 1);

      case 'c2_goal':
        final goal = goals.where((g) => g.id == str('goal')).firstOrNull;
        if (goal == null) throw StoryRuleError('unknown goal');
        return s
            .copyWith(goalId: goal.id, goalTarget: goal.target)
            .scored(1, 1);

      case 'c2_treat':
        if (!const ['join', 'small', 'skip'].contains(str('option'))) {
          throw StoryRuleError('unknown option');
        }
        return s.withFlag('c2_treat', str('option')).scored(1, 1);

      case 'c2_week1' || 'c2_week2' || 'c2_week3' || 'c2_week4':
        final week = int.parse(id.substring(id.length - 1));
        final save = i('save');
        if (save < 0 || save > c2Income(s, week) || save % 10 != 0) {
          throw StoryRuleError('cannot save $save in week $week');
        }
        var next = save > 0 ? _move(s, 'jar', 'txn_week_save', save) : s;
        next = next
            .withNum('c2_w$week', save)
            .withNum('c2_total', s.n('c2_total') + save);
        if (week < 4) return next;
        final weeks = [
          for (var w = 1; w <= 4; w++)
            if (next.n('c2_w$w') > 0) w,
        ].length;
        final habit = (((next.n('c2_total') / 4) / 50).round() * 50).clamp(
          50,
          300,
        );
        return next
            .copyWith(monthlySave: habit)
            .scored(weeks >= 3 ? 2 : (weeks >= 1 ? 1 : 0), 2);

      case 'c3_open':
        final moved = s.jar;
        var next = s;
        if (moved > 0) {
          next = _move(next, 'jar', 'txn_open_deposit', -moved);
          next = _move(next, 'bank', 'txn_open_deposit', moved);
        }
        return _move(next, 'bank', 'txn_nanna', openingGift);

      case 'c3_bank':
        var next = _move(s, 'wallet', 'txn_deposit', -depositAmount);
        next = _move(next, 'bank', 'txn_deposit', depositAmount);
        next = _move(next, 'bank', 'txn_withdraw', -withdrawAmount);
        next = _move(next, 'wallet', 'txn_withdraw', withdrawAmount);
        next = _move(next, 'bank', 'txn_upi_shop', -upiAmount);
        return next
            .withNum('c3_after3', next.bank)
            .scored(i('slips') == 0 ? 2 : 1, 2)
            .scored(b('predict') ? 1 : 0, 1);

      case 'c3_pending':
        var next = _move(s, 'bank', 'txn_fair_fee', -fairFee);
        switch (str('path')) {
          case 'verify':
            return next.withFlag('c3_pending', 'verify').scored(2, 2);
          case 'double':
            next = _move(next, 'bank', 'txn_fair_fee_again', -fairFee);
          case 'cash':
            next = _move(next, 'wallet', 'txn_fair_fee_cash', -fairFee);
          default:
            throw StoryRuleError('unknown path');
        }
        return _move(
          next,
          'wallet',
          'txn_fee_refund',
          fairFee,
        ).withFlag('c3_pending', str('path')).scored(0, 2);

      case 'c4_inbox':
        var next = s;
        var points = 0;
        var unsafe = 0;
        var lost = 0;
        for (final m in scamAmounts.keys) {
          final decision = str(m);
          switch (decision) {
            case 'verify' || 'report':
              points += 2;
            case 'ignore':
              points += 1;
            case 'proceed':
              unsafe++;
              final loss = min(scamAmounts[m]!, next.bank);
              lost += loss;
              if (loss > 0) next = _move(next, 'bank', 'txn_scam_$m', -loss);
            default:
              throw StoryRuleError('no decision for $m');
          }
          next = next.withFlag('c4_$m', decision);
        }
        final clues = i('clues');
        return next
            .withNum('c4_unsafe', unsafe)
            .withNum('c4_safe', scamAmounts.length - unsafe)
            .withNum('c4_lost', lost)
            .copyWith(hints: next.hints + i('hints'))
            .scored(points, 8)
            .scored(clues >= 8 ? 2 : (clues >= 4 ? 1 : 0), 2);

      case 'c4_recover':
        final back = max(
          0,
          s.n('c4_lost') - scamUnrecovered * s.n('c4_unsafe'),
        );
        final next = back > 0 ? _move(s, 'bank', 'txn_recovered', back) : s;
        return next
            .withNum('c4_back', back)
            .withNum('c4_gone', s.n('c4_lost') - back);

      case 'c5_shop':
        final item = str('item');
        final method = str('method');
        if (!c5CanPay(s, item, method)) {
          throw StoryRuleError('cannot buy $item with $method');
        }
        var next = s;
        if (item != 'wait') {
          final price = priceOf(item);
          next = switch (method) {
            'debit' => _move(next, 'bank', 'txn_buy_$item', -price),
            'cash' => _move(next, 'wallet', 'txn_buy_$item', -price),
            _ => _move(next, 'credit', 'txn_buy_$item', price),
          };
        }
        return next
            .withFlag('c5_item', item)
            .withFlag('c5_method', method)
            .scored(i('inspected') >= 3 ? 2 : 1, 2);

      case 'c5_statement':
        var next = s
            .scored(b('predict') ? 1 : 0, 1)
            .scored(b('explored') ? 1 : 0, 1);
        if (s.debt == 0) return next;
        final pay = i('pay');
        if (!c5PayOptions(s).contains(pay)) {
          throw StoryRuleError('cannot pay $pay');
        }
        final floor = minPayment(s.debt);
        if (pay > 0) {
          next = _move(next, 'bank', 'txn_credit_pay', -pay);
          next = _move(next, 'credit', 'txn_credit_pay', -pay);
        }
        return next
            .copyWith(creditPlan: max(pay, floor))
            .withFlag(
              'c5_pay',
              next.debt == 0 ? 'full' : (pay > floor ? 'more' : 'min'),
            );

      case 'c6_compare':
        return s.scored(b('predict') ? 1 : 0, 1);

      case 'c6_fd':
        final amount = i('amount');
        if (!c6FdOptions(s).contains(amount)) {
          throw StoryRuleError('cannot lock $amount');
        }
        var next = s;
        if (amount > 0) {
          next = _move(next, 'bank', 'txn_fd_open', -amount);
          next = _move(next, 'fd', 'txn_fd_open', amount);
        }
        return next
            .withNum('c6_fd', amount)
            .scored(next.bank >= surpriseCost ? 1 : 0, 1);

      case 'c6_time':
        final event = str('event');
        final months = c6Months(s, event);
        var next = months.last;
        final lowest = [s, ...months].map((m) => m.bank).reduce(min);
        var fdInterest = 0;
        if (next.fd > 0) {
          final principal = next.fd;
          fdInterest = simpleInterest(principal, fdRatePercent, fdMonths);
          next = _move(next, 'fd', 'txn_fd_mature', -principal);
          next = _move(next, 'bank', 'txn_fd_mature', principal + fdInterest);
        }
        final savingsInterest = simpleInterest(
          lowest,
          savingsRatePercent,
          fdMonths,
        );
        if (savingsInterest > 0) {
          next = _move(next, 'bank', 'txn_savings_interest', savingsInterest);
        }
        final owed = min(next.n('c6_owe'), next.bank);
        if (owed > 0) next = _move(next, 'bank', 'txn_repay_amma', -owed);
        return next
            .withFlag('c6_event', event)
            .withNum('c6_fd_interest', fdInterest)
            .withNum('c6_sav_interest', savingsInterest)
            .scored(event == 'savings' ? 2 : 1, 2);

      case 'c7_policy':
        return s
            .withFlag('c7_claim', b('claim') ? 'tried' : 'no')
            .scored(b('claim') ? 0 : 1, 1)
            .scored(b('calc') ? 1 : 0, 1);

      case 'c7_addon':
        final option = str('option');
        if (!const ['keep', 'addon', 'drop'].contains(option)) {
          throw StoryRuleError('unknown option');
        }
        return s
            .withFlag('c7_policy', option)
            .scored(option == 'drop' ? 0 : 1, 1);

      case 'c7_plan':
        final asha = i('asha');
        if (asha < 0 || asha > c7AshaMax(s) || asha % 100 != 0) {
          throw StoryRuleError('cannot give $asha');
        }
        final total = c7PlanTotal(
          fund: b('fund'),
          eatOut: b('eatOut'),
          tv: b('tv'),
          uncle: b('uncle'),
          asha: asha,
        );
        if (total < clinicBill) throw StoryRuleError('bill is not covered');
        var next = asha > 0 ? _move(s, 'bank', 'txn_clinic', -asha) : s;
        for (final key in const ['fund', 'eatOut', 'tv', 'uncle']) {
          if (b(key)) next = next.withFlag('c7_$key', '1');
        }
        return next
            .withNum('c7_asha', asha)
            .withNum('c7_total', total)
            .scored(i('tries') == 0 ? 1 : 0, 1)
            .scored(b('fund') ? 1 : 0, 1);
    }
    throw StoryRuleError('unknown beat $id');
  }

  /// Values available to every story text as `{name}` placeholders.
  static Map<String, Object> params(StoryState s) => {
    ...s.nums,
    'wallet': s.wallet,
    'jar': s.jar,
    'bank': s.bank,
    'fd': s.fd,
    'debt': s.debt,
    'savings': s.savings,
    'plan': s.creditPlan,
    'habit': s.monthlySave,
    'target': s.goalTarget,
    'interest_paid': s.interestPaid,
  };

  static StoryState _move(
    StoryState s,
    String account,
    String label,
    int amount,
  ) {
    final before = switch (account) {
      'wallet' => s.wallet,
      'jar' => s.jar,
      'bank' => s.bank,
      'fd' => s.fd,
      'credit' => s.debt,
      _ => throw StoryRuleError('unknown account $account'),
    };
    final after = before + amount;
    if (after < 0) throw StoryRuleError('$account cannot go below zero');
    final txns = [
      ...s.txns,
      Txn(
        chapter: s.chapter,
        account: account,
        label: label,
        amount: amount,
        balanceAfter: after,
      ),
    ];
    return switch (account) {
      'wallet' => s.copyWith(wallet: after, txns: txns),
      'jar' => s.copyWith(jar: after, txns: txns),
      'bank' => s.copyWith(bank: after, txns: txns),
      'fd' => s.copyWith(fd: after, txns: txns),
      _ => s.copyWith(debt: after, txns: txns),
    };
  }
}
