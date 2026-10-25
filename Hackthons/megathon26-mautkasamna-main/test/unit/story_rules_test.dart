import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/features/story/domain/story_rules.dart';
import 'package:gullak/features/story/domain/story_script.dart';
import 'package:gullak/features/story/domain/story_state.dart';
import 'package:gullak/features/story/presentation/activities/activities.dart';

/// What a simulated player reports for each interactive beat.
typedef Policy = Map<String, Object?> Function(String id, StoryState s);

Map<String, Object?> careful(String id, StoryState s) => switch (id) {
  'c1_budget' => {
    'items': ['bus', 'lunch', 'recharge', 'movie'],
    'tries': 0,
  },
  'c1_form' => {'option': s.wallet >= 60 ? 'own' : 'advance'},
  'c2_goal' => {'goal': 'kit'},
  'c2_treat' => {'option': 'small'},
  'c2_week1' || 'c2_week2' || 'c2_week3' || 'c2_week4' => {'save': 150},
  'c3_bank' => {'slips': 0, 'predict': true},
  'c3_pending' => {'path': 'verify'},
  'c4_inbox' => {
    for (final m in StoryRules.scamAmounts.keys) m: 'verify',
    'clues': 12,
  },
  'c5_shop' =>
    s.bank >= StoryRules.litePrice
        ? {'item': 'lite', 'method': 'debit', 'inspected': 3}
        : {'item': 'wait', 'method': 'none', 'inspected': 3},
  'c5_statement' => {'pay': 0, 'predict': true, 'explored': true},
  'c6_compare' => {'predict': true},
  'c6_fd' => {
    'amount': StoryRules.c6FdOptions(
      s,
    ).lastWhere((a) => s.bank - a >= StoryRules.surpriseCost, orElse: () => 0),
  },
  'c6_time' => {
    'event': StoryRules.c6EventOptions(StoryRules.c6Months(s, null).last).first,
  },
  'c7_policy' => {'claim': false, 'calc': true},
  'c7_addon' => {'option': 'keep'},
  'c7_plan' => {
    'fund': true,
    'eatOut': true,
    'tv': true,
    'uncle': true,
    'asha': 0,
  },
  _ => const {},
};

Map<String, Object?> reckless(String id, StoryState s) => switch (id) {
  'c1_budget' => {
    'items': ['bus', 'lunch', 'recharge', 'headphones', 'chaat'],
    'tries': 2,
  },
  'c1_form' => {'option': 'advance'},
  'c1_sort' || 'c4_rules' => {'mistakes': 3},
  'c2_goal' => {'goal': 'laptop'},
  'c2_treat' => {'option': 'join'},
  'c2_week1' || 'c2_week2' || 'c2_week3' || 'c2_week4' => {'save': 0},
  'c3_bank' => {'slips': 4, 'predict': false},
  'c3_pending' => {'path': 'double'},
  'c4_inbox' => {
    for (final m in StoryRules.scamAmounts.keys) m: 'proceed',
    'hints': 4,
  },
  'c5_shop' => {'item': 'nova', 'method': 'credit', 'inspected': 1},
  'c5_statement' => {'pay': StoryRules.c5PayOptions(s).first},
  'c6_fd' => {'amount': StoryRules.c6FdOptions(s).last},
  'c6_time' => {
    'event': StoryRules.c6EventOptions(StoryRules.c6Months(s, null).last).last,
  },
  'c7_policy' => {'claim': true, 'calc': false},
  'c7_addon' => {'option': 'drop'},
  'c7_plan' => {
    'fund': true,
    'eatOut': true,
    'uncle': true,
    'asha': 0,
    'tries': 2,
  },
  _ => const {},
};

/// Plays the whole story with [policy], checking invariants at every beat.
StoryState playStory(Policy policy, {void Function(StoryState s)? onBeat}) {
  var s = StoryRules.newStory();
  var steps = 0;
  while (!s.finished) {
    expect(steps++, lessThan(400), reason: 'story did not finish');
    final chapter = chapterByNumber(s.chapter);
    final at = chapter.nextBeat(s, s.beat);
    expect(at, lessThan(chapter.beats.length), reason: 'ran off the script');
    final beat = chapter.beats[at];
    switch (beat) {
      case Play():
        s = StoryRules.apply(s, beat.id, policy(beat.id, s));
      case Pick():
        s = StoryRules.apply(s, beat.id, policy(beat.id, s));
      case Talk() || Teach():
        break;
      case Recap():
        s = StoryRules.finishChapter(s);
        onBeat?.call(s);
        continue;
    }
    s = s.copyWith(beat: at + 1);
    for (final balance in [s.wallet, s.jar, s.bank, s.fd, s.debt]) {
      expect(balance, greaterThanOrEqualTo(0));
    }
    onBeat?.call(s);
  }
  return s;
}

void main() {
  StoryState afterBudget(List<String> items) =>
      StoryRules.apply(StoryRules.newStory(), 'c1_budget', {'items': items});

  group('chapter 1: the first ₹1,000', () {
    test('expenses reduce the wallet and the rest is savings', () {
      final s = afterBudget(['bus', 'lunch', 'recharge', 'movie']);
      expect(s.wallet, 200);
      expect(s.n('c1_spent'), 800);
      expect(s.n('c1_left'), 200);
      expect(s.has('c1_movie'), isTrue);
      expect(s.txns.map((t) => t.amount), [1000, -200, -250, -150, -200]);
      expect(s.txns.last.balanceAfter, 200);
    });

    test('needs only saves ₹400; spending everything leaves nothing', () {
      expect(afterBudget(['bus', 'lunch', 'recharge']).wallet, 400);
      expect(
        afterBudget(['bus', 'lunch', 'recharge', 'headphones', 'chaat']).wallet,
        0,
      );
    });

    test('an over-budget plan or a missing need is refused unchanged', () {
      final all = [for (final e in StoryRules.c1Items) e.id];
      expect(StoryRules.c1Total(all), 1200);
      expect(() => afterBudget(all), throwsA(isA<StoryRuleError>()));
      expect(StoryRules.c1MissingNeeds(['bus', 'movie']), [
        'lunch',
        'recharge',
      ]);
      expect(
        () => afterBudget(['bus', 'movie']),
        throwsA(isA<StoryRuleError>()),
      );
      expect(() => afterBudget(['bus', 'rocket']), throwsA(anything));
    });

    test('the same expense listed twice is charged once', () {
      expect(afterBudget(['bus', 'bus', 'lunch', 'recharge']).wallet, 400);
    });

    test('the ₹60 form: own money, or an advance carried to week 1', () {
      final rich = afterBudget(['bus', 'lunch', 'recharge']);
      final own = StoryRules.apply(rich, 'c1_form', {'option': 'own'});
      expect(own.wallet, 340);
      final advance = StoryRules.apply(rich, 'c1_form', {'option': 'advance'});
      expect(advance.wallet, 400);
      expect(StoryRules.c2Income(advance, 1), 240);
      expect(StoryRules.c2Income(own, 1), 300);

      final broke = afterBudget([
        'bus',
        'lunch',
        'recharge',
        'headphones',
        'chaat',
      ]);
      expect(
        () => StoryRules.apply(broke, 'c1_form', {'option': 'own'}),
        throwsA(isA<StoryRuleError>()),
      );
    });

    test('finishing moves the leftover into the gullak and adds the gift', () {
      final played = StoryRules.apply(
        afterBudget(['bus', 'lunch', 'recharge', 'movie']),
        'c1_form',
        {'option': 'own'},
      );
      final next = StoryRules.finishChapter(played);
      expect(next.chapter, 2);
      expect(next.beat, 0);
      expect(next.wallet, 0);
      expect(next.jar, 140 + StoryRules.giftAmount);
      expect(next.done, {1: 3});
      expect(next.score, 0, reason: 'each chapter is scored on its own');
    });
  });

  group('chapter 2: the laptop dream', () {
    StoryState chapter2({String treat = 'skip'}) => StoryRules.apply(
      StoryRules.apply(
        StoryRules.startChapter(const StoryState(jar: 400), 2),
        'c2_goal',
        {'goal': 'course'},
      ),
      'c2_treat',
      {'option': treat},
    );

    test('opens with ₹500 when ₹400 was saved in chapter 1', () {
      expect(chapter2().jar, 500);
      expect(chapter2().goalTarget, 1500);
    });

    test('weekly money after fixed costs', () {
      expect(StoryRules.c2Income(chapter2(), 2), 300);
      expect(StoryRules.c2Income(chapter2(treat: 'join'), 2), 200);
      expect(StoryRules.c2Income(chapter2(treat: 'small'), 2), 270);
      expect(StoryRules.c2Income(chapter2(), 3), 220);
      expect(StoryRules.c2Income(chapter2(), 4), 300);
    });

    test('four weeks of saving accumulate and set the habit', () {
      var s = chapter2();
      for (final (week, save) in [(1, 300), (2, 300), (3, 220), (4, 300)]) {
        s = StoryRules.apply(s, 'c2_week$week', {'save': save});
      }
      expect(s.jar, 500 + 1120);
      expect(s.n('c2_total'), 1120);
      expect(s.monthlySave, 300);
    });

    test('saving more than the week allows is refused', () {
      expect(
        () => StoryRules.apply(chapter2(), 'c2_week3', {'save': 230}),
        throwsA(isA<StoryRuleError>()),
      );
      expect(
        () => StoryRules.apply(chapter2(), 'c2_week1', {'save': -10}),
        throwsA(isA<StoryRuleError>()),
      );
    });

    test('time to goal', () {
      expect(StoryRules.weeksToGoal(1500, 500, 300), 4);
      expect(StoryRules.weeksToGoal(1500, 500, 200), 5);
      expect(StoryRules.weeksToGoal(1000, 1000, 0), 0);
      expect(StoryRules.weeksToGoal(3000, 500, 0), isNull);
    });
  });

  group('chapter 3: digital money', () {
    StoryState opened(int jar) => StoryRules.apply(
      StoryRules.startChapter(StoryState(jar: jar), 3),
      'c3_open',
      const {},
    );

    test('₹1,500 → deposit 300, withdraw 200, UPI 150 → ₹1,450', () {
      final start = opened(1300);
      expect(start.bank, 1500);
      expect(start.jar, 0);
      final s = StoryRules.apply(start, 'c3_bank', const {});
      expect(s.bank, 1450);
      expect(s.wallet, 200);
      expect(s.n('c3_after3'), 1450);
      expect(
        s.txns.where((t) => t.account == 'bank').map((t) => t.balanceAfter),
        [1300, 1500, 1800, 1600, 1450],
      );
    });

    test('pending payment: verifying pays once', () {
      final s = StoryRules.apply(
        StoryRules.apply(opened(1300), 'c3_bank', const {}),
        'c3_pending',
        {'path': 'verify'},
      );
      expect(s.bank, 1350);
      expect(s.wallet, 200);
    });

    test(
      'pending payment: paying again debits twice, refund comes as cash',
      () {
        final base = StoryRules.apply(opened(1300), 'c3_bank', const {});
        final twice = StoryRules.apply(base, 'c3_pending', {'path': 'double'});
        expect(twice.bank, 1250);
        expect(twice.wallet, 300);
        final cash = StoryRules.apply(base, 'c3_pending', {'path': 'cash'});
        expect(cash.bank, 1350);
        expect(cash.wallet, 200);
        expect(cash.flag('c3_pending'), 'cash');
      },
    );

    test('even the smallest possible gullak covers the chapter', () {
      final s = StoryRules.apply(
        StoryRules.apply(opened(100), 'c3_bank', const {}),
        'c3_pending',
        {'path': 'double'},
      );
      expect(s.bank, 50);
    });
  });

  group('chapter 4: suspicious messages', () {
    final base = const StoryState(chapter: 4, bank: 1350);
    Map<String, Object?> inbox(String m1, String m2, String m3, String m4) => {
      'm1': m1,
      'm2': m2,
      'm3': m3,
      'm4': m4,
    };

    test('safe decisions cost nothing', () {
      final s = StoryRules.apply(
        base,
        'c4_inbox',
        inbox('verify', 'report', 'ignore', 'verify'),
      );
      expect(s.bank, 1350);
      expect(s.n('c4_unsafe'), 0);
      expect(s.n('c4_safe'), 4);
    });

    test('an unsafe choice loses money; reporting recovers all but ₹50', () {
      final hit = StoryRules.apply(
        base,
        'c4_inbox',
        inbox('proceed', 'verify', 'verify', 'verify'),
      );
      expect(hit.bank, 1150);
      final back = StoryRules.apply(hit, 'c4_recover', const {});
      expect(back.bank, 1300);
      expect(back.n('c4_back'), 150);
      expect(back.n('c4_gone'), 50);
    });

    test('losses never take the balance below zero', () {
      final hit = StoryRules.apply(
        const StoryState(chapter: 4, bank: 600),
        'c4_inbox',
        inbox('proceed', 'proceed', 'proceed', 'proceed'),
      );
      expect(hit.bank, 0);
      expect(hit.n('c4_lost'), 600);
      final back = StoryRules.apply(hit, 'c4_recover', const {});
      expect(back.bank, 400);
    });

    test('every message needs a decision', () {
      expect(
        () => StoryRules.apply(base, 'c4_inbox', {'m1': 'verify'}),
        throwsA(isA<StoryRuleError>()),
      );
    });
  });

  group('chapter 5: buy now or wait', () {
    final base = const StoryState(chapter: 5, bank: 1300, wallet: 200);

    test('debit uses own money; credit creates a debt', () {
      final debit = StoryRules.apply(base, 'c5_shop', {
        'item': 'lite',
        'method': 'debit',
      });
      expect(debit.bank, 100);
      expect(debit.debt, 0);
      final credit = StoryRules.apply(base, 'c5_shop', {
        'item': 'nova',
        'method': 'credit',
      });
      expect(credit.bank, 1300);
      expect(credit.debt, 3000);
      final wait = StoryRules.apply(base, 'c5_shop', {
        'item': 'wait',
        'method': 'none',
      });
      expect(wait.bank, 1300);
    });

    test('paying with money Asha does not have is refused', () {
      expect(StoryRules.c5CanPay(base, 'nova', 'debit'), isFalse);
      expect(StoryRules.c5CanPay(base, 'lite', 'cash'), isFalse);
      expect(
        () => StoryRules.apply(base, 'c5_shop', {
          'item': 'nova',
          'method': 'debit',
        }),
        throwsA(isA<StoryRuleError>()),
      );
    });

    test('minimum payment and monthly interest', () {
      expect(StoryRules.minPayment(3000), 300);
      expect(StoryRules.minPayment(1200), 120);
      expect(StoryRules.minPayment(1234), 130);
      expect(StoryRules.minPayment(500), 100);
      expect(StoryRules.minPayment(80), 80);
      expect(StoryRules.monthlyInterest(2700), 81);
      expect(StoryRules.monthlyInterest(0), 0);
    });

    test('paying in full by the due date costs no interest', () {
      final plan = StoryRules.repaySchedule(3000, 3000);
      expect(plan.months, 1);
      expect(plan.totalInterest, 0);
      expect(plan.totalPaid, 3000);
    });

    test('paying only the minimum costs more in total', () {
      final plan = StoryRules.repaySchedule(3000, 300);
      // Worked out separately: 2700 → 2481 → 2255 → 2023 → 1784 → 1538 → 1284 →
      // 1023 → 754 → 477 → 191 → 0, with 3% added before each payment.
      expect(plan.months, 12);
      expect(plan.totalInterest, 497);
      expect(plan.totalPaid, 3497);
      expect(plan.endless, isFalse);
      expect(
        StoryRules.repaySchedule(3000, 600).totalInterest,
        lessThan(plan.totalInterest),
      );
    });

    test('a payment smaller than the interest never clears the debt', () {
      expect(StoryRules.repaySchedule(10000, 100).endless, isTrue);
    });

    test('the first statement payment sets the monthly plan', () {
      final owing = StoryRules.apply(base, 'c5_shop', {
        'item': 'nova',
        'method': 'credit',
      });
      expect(StoryRules.c5PayOptions(owing), [300, 1300]);
      final paid = StoryRules.apply(owing, 'c5_statement', {'pay': 300});
      expect(paid.bank, 1000);
      expect(paid.debt, 2700);
      expect(paid.creditPlan, 300);
      expect(paid.flag('c5_pay'), 'min');
      expect(
        () => StoryRules.apply(owing, 'c5_statement', {'pay': 5000}),
        throwsA(isA<StoryRuleError>()),
      );

      final small = StoryRules.apply(base, 'c5_shop', {
        'item': 'lite',
        'method': 'credit',
      });
      expect(StoryRules.c5PayOptions(small), [120, 600, 1200]);
      final cleared = StoryRules.apply(small, 'c5_statement', {'pay': 1200});
      expect(cleared.debt, 0);
      expect(cleared.flag('c5_pay'), 'full');
    });

    test('a sample statement changes nothing', () {
      final s = StoryRules.apply(base, 'c5_statement', {'pay': 0});
      expect(s.bank, base.bank);
      expect(s.txns, isEmpty);
    });
  });

  group('chapter 6: make your money work', () {
    test('simple interest on ₹2,000 for six months: ₹30 and ₹60', () {
      expect(StoryRules.simpleInterest(2000, 3, 6), 30);
      expect(StoryRules.simpleInterest(2000, 6, 6), 60);
      expect(StoryRules.simpleInterest(2000, 6, 3), 30);
      expect(StoryRules.simpleInterest(0, 6, 6), 0);
    });

    test('a month: savings arrive, then credit interest and repayment', () {
      final s = StoryRules.monthTick(
        const StoryState(
          chapter: 6,
          bank: 500,
          debt: 2700,
          creditPlan: 300,
          monthlySave: 100,
        ),
      );
      expect(s.bank, 300);
      expect(s.debt, 2481);
      expect(s.interestPaid, 81);
    });

    test('a repayment never takes more than the bank holds', () {
      final s = StoryRules.monthTick(
        const StoryState(chapter: 6, bank: 20, debt: 1000, creditPlan: 300),
      );
      expect(s.bank, 0);
      expect(s.debt, 1010);
    });

    StoryState locked() => StoryRules.apply(
      const StoryState(chapter: 6, bank: 2000, monthlySave: 100),
      'c6_fd',
      {'amount': 1000},
    );

    test('locking money moves it out of reach', () {
      expect(locked().bank, 1000);
      expect(locked().fd, 1000);
      expect(StoryRules.c6FdOptions(const StoryState(bank: 1200)), [
        0,
        500,
        1000,
      ]);
      expect(
        () => StoryRules.apply(locked(), 'c6_fd', {'amount': 1500}),
        throwsA(isA<StoryRuleError>()),
      );
    });

    test('paying the surprise from savings keeps the deposit interest', () {
      final s = StoryRules.apply(locked(), 'c6_time', {'event': 'savings'});
      expect(s.n('c6_fd_interest'), 30);
      expect(s.n('c6_sav_interest'), 15);
      expect(s.fd, 0);
      // 1000 + 6×100 − 300 + (1000 + 30) + 15
      expect(s.bank, 2345);
    });

    test('breaking the deposit early loses its interest', () {
      final s = StoryRules.apply(locked(), 'c6_time', {'event': 'break'});
      expect(s.n('c6_fd_interest'), 0);
      expect(s.has('c6_broke'), isTrue);
      // 1000 + 6×100 + 1000 − 300 + 15
      expect(s.bank, 2315);
    });

    test('borrowing from Amma is repaid at the end', () {
      final s = StoryRules.apply(locked(), 'c6_time', {'event': 'family'});
      // 1000 + 6×100 + 1030 + 15 − 300
      expect(s.bank, 2345);
      expect(s.txns.last.label, 'txn_repay_amma');
    });

    test('only affordable ways to pay the surprise are offered', () {
      final thin = StoryRules.apply(
        const StoryState(chapter: 6, bank: 500),
        'c6_fd',
        {'amount': 500},
      );
      final month3 = StoryRules.c6Months(thin, null).last;
      expect(StoryRules.c6EventOptions(month3), ['break', 'family']);
      expect(
        () => StoryRules.apply(thin, 'c6_time', {'event': 'savings'}),
        throwsA(isA<StoryRuleError>()),
      );
      expect(StoryRules.c6Months(thin, null), hasLength(3));
      expect(StoryRules.c6Months(thin, 'break'), hasLength(6));
    });

    test('store credit keeps charging through the six months', () {
      final s = StoryRules.apply(
        const StoryState(
          chapter: 6,
          bank: 1000,
          debt: 2700,
          creditPlan: 300,
          monthlySave: 100,
        ),
        'c6_time',
        {'event': 'family'},
      );
      // The bank runs dry in month 6, so only ₹100 of the ₹300 is repaid.
      expect(s.debt, 1484);
      expect(s.interestPaid, 384);
      expect(s.bank, 0);
    });
  });

  group('chapter 7: when plans change', () {
    test('what the policy pays', () {
      expect(StoryRules.policyPays(1000, hospitalStay: false), 0);
      expect(StoryRules.policyPays(6000, hospitalStay: true), 5500);
      expect(StoryRules.policyPays(8000, hospitalStay: true), 7500);
      expect(StoryRules.policyPays(400, hospitalStay: true), 0);
      expect(StoryRules.policyPays(50000, hospitalStay: true), 20000);
    });

    test(
      'the plan must cover the bill, and only Asha’s part leaves her bank',
      () {
        const s = StoryState(chapter: 7, bank: 850);
        expect(StoryRules.c7AshaMax(s), 500);
        expect(StoryRules.c7AshaMax(const StoryState(bank: 250)), 200);
        expect(
          () => StoryRules.apply(s, 'c7_plan', {'fund': true, 'tv': true}),
          throwsA(isA<StoryRuleError>()),
        );
        expect(
          () => StoryRules.apply(s, 'c7_plan', {'fund': true, 'asha': 600}),
          throwsA(isA<StoryRuleError>()),
        );
        final paid = StoryRules.apply(s, 'c7_plan', {
          'fund': true,
          'eatOut': true,
          'asha': 300,
        });
        expect(paid.bank, 550);
        expect(paid.n('c7_total'), 1000);
        expect(paid.has('c7_fund'), isTrue);
        expect(paid.has('c7_uncle'), isFalse);
      },
    );
  });

  group('the whole story', () {
    test('a careful player finishes with consistent money', () {
      final s = playStory(careful);
      expect(s.finished, isTrue);
      expect(s.done.keys, [1, 2, 3, 4, 5, 6, 7]);
      expect(s.done.values.every((stars) => stars == 3), isTrue);
      expect(s.debt, 0);
      // Saving ₹150 a week is not enough for the ₹1,200 Lite, so this
      // player keeps saving and uses the lab laptop.
      expect(s.flag('c5_item'), 'wait');
      expect(s.bank, greaterThan(1200));
    });

    test('a reckless player still reaches the end and can recover', () {
      final s = playStory(reckless);
      expect(s.finished, isTrue);
      expect(s.done.length, 7);
      expect(s.done.values.every((stars) => stars >= 1 && stars <= 3), isTrue);
      expect(s.flag('c5_item'), 'nova');
      expect(s.debt, greaterThan(0));
      expect(s.n('c4_unsafe'), 4);
    });

    test('money is never created or lost between beats', () {
      // Every balance always equals the sum of its diary entries.
      for (final policy in [careful, reckless]) {
        playStory(
          policy,
          onBeat: (s) {
            int sum(String account) => s.txns
                .where((t) => t.account == account)
                .fold(0, (total, t) => total + t.amount);
            expect(sum('wallet'), s.wallet);
            expect(sum('jar'), s.jar);
            expect(sum('bank'), s.bank);
            expect(sum('fd'), s.fd);
            expect(sum('credit'), s.debt);
          },
        );
      }
    });

    test('the save format round-trips at every checkpoint', () {
      playStory(
        reckless,
        onBeat: (s) =>
            expect(StoryState.decode(s.encode()).encode(), s.encode()),
      );
    });

    test('rules are deterministic', () {
      expect(playStory(careful).encode(), playStory(careful).encode());
    });

    test('an unknown beat is refused', () {
      expect(
        () => StoryRules.apply(const StoryState(), 'c9_nothing', const {}),
        throwsA(isA<StoryRuleError>()),
      );
    });
  });

  group('script', () {
    test('seven chapters, each ending in a recap', () {
      expect(storyChapters.map((c) => c.number), [1, 2, 3, 4, 5, 6, 7]);
      for (final chapter in storyChapters) {
        expect(chapter.beats.last, isA<Recap>());
        expect(chapter.beats.whereType<Recap>(), hasLength(1));
        expect(chapter.beats.first, isA<Talk>());
        expect(chapter.beats.whereType<Teach>(), hasLength(1));
        expect(
          chapter.beats.whereType<Play>().length,
          greaterThanOrEqualTo(2),
          reason: 'chapter ${chapter.number} needs real activities',
        );
      }
    });

    test('every activity in the script has a screen', () {
      final used = {
        for (final chapter in storyChapters)
          for (final beat in chapter.beats.whereType<Play>()) beat.id,
      };
      expect(used.difference(activityIds), isEmpty);
      expect(activityIds.difference(used), isEmpty);
    });

    test('every decision has a way forward', () {
      for (final chapter in storyChapters) {
        for (final pick in chapter.beats.whereType<Pick>()) {
          expect(
            pick.options.where((o) => !o.retry && o.enabled == null),
            isNotEmpty,
            reason: pick.id,
          );
        }
      }
    });
  });
}
