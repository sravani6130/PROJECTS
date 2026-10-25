import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/game/characters.dart';
import '../../../../core/game/game_style.dart';
import '../../../../core/game/game_tokens.dart';
import '../../../../core/game/game_widgets.dart';
import '../../../../core/game/props.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/story_rules.dart';
import '../story_widgets.dart';
import 'activity_base.dart';

/// Chapter 5: inspect three ways to get a laptop, then check out.
class ShopActivity extends ActivityWidget {
  const ShopActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<ShopActivity> createState() => _ShopActivityState();
}

class _ShopActivityState extends ConsumerState<ShopActivity>
    with ActivityHelpers {
  String? _item;
  String? _method;
  bool _paying = false;
  final _inspected = <String>{};

  Map<String, Object?> _result(String method) => {
    'item': _item,
    'method': method,
    'inspected': _inspected.length,
  };

  List<Widget> _details(String item) {
    final s = widget.s;
    if (item == 'wait') {
      final months = StoryRules.weeksToGoal(
        StoryRules.novaPrice,
        s.savings,
        s.monthlySave,
      );
      return [
        FactRow(label: t('c5_pay_now'), value: formatRupees(0)),
        FactRow(label: t('c5_bank_after'), value: formatRupees(s.bank)),
        Text(
          tx('c5_wait_note', {'months': months ?? 0}),
          style: const TextStyle(height: 1.25),
        ),
      ];
    }
    final price = StoryRules.priceOf(item);
    final plan = StoryRules.repaySchedule(price, StoryRules.minPayment(price));
    return [
      FactRow(label: t('c5_your_share'), value: formatRupees(price)),
      s.bank >= price
          ? FactRow(
              label: t('c5_bank_after'),
              value: formatRupees(s.bank - price),
            )
          : FactRow(
              label: t('c5_short_by'),
              value: formatRupees(price - s.bank),
              color: Toon.berry,
            ),
      const Divider(),
      Text(
        tx('c5_credit_note', {
          'min': StoryRules.minPayment(price),
          'months': plan.months,
          'total': plan.totalPaid,
          'interest': plan.totalInterest,
        }),
        style: const TextStyle(height: 1.25),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    if (_paying && _item != null) {
      final price = StoryRules.priceOf(_item!);
      return BeatLayout(
        guide: guide('c5_pay_intro', who: 'imran', mood: Mood.happy),
        panel: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const PropIcon(PropKind.laptop, size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t('c5_opt_$_item'),
                    style: toonTitle(context, size: 17),
                  ),
                ),
                Text(formatRupees(price), style: toonTitle(context, size: 20)),
              ],
            ),
            const SizedBox(height: Gap.sm),
            for (final (method, prop) in const [
              ('debit', PropKind.bank),
              ('cash', PropKind.coin),
              ('credit', PropKind.card),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Opacity(
                  opacity: StoryRules.c5CanPay(s, _item!, method) ? 1 : 0.45,
                  child: ChoiceTile(
                    key: ValueKey('pay_$method'),
                    prop: prop,
                    label: StoryRules.c5CanPay(s, _item!, method)
                        ? t('c5_m_$method')
                        : '${t('c5_m_$method')} — ${tx('c5_not_enough', {'have': method == 'cash' ? s.wallet : s.bank})}',
                    selected: _method == method,
                    onTap: () {
                      if (!StoryRules.c5CanPay(s, _item!, method)) return;
                      tapFeedback();
                      setState(() => _method = method);
                    },
                  ),
                ),
              ),
            if (_method != null)
              ToneBanner(
                key: const ValueKey('pay_preview'),
                tone: _method == 'credit' ? Tone.risky : Tone.okay,
                title: t(
                  _method == 'credit' ? 'c5_borrowed_money' : 'c5_own_money',
                ),
                text: tx('c5_prev_$_method', {
                  'price': price,
                  'after': _method == 'debit'
                      ? s.bank - price
                      : s.wallet - price,
                }),
              ),
            TextButton(
              key: const ValueKey('shop_back'),
              onPressed: () => setState(() {
                _paying = false;
                _method = null;
              }),
              child: Text(t('c5_back_compare')),
            ),
          ],
        ),
        bottom: doneButton(
          'c5_pay_btn',
          extra: {'price': price},
          result: _method == null ? null : () => _result(_method!),
        ),
      );
    }

    return BeatLayout(
      guide: guide('c5_shop_intro', mood: Mood.thinking),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tx('c5_inspected', {'n': _inspected.length}),
            key: const ValueKey('shop_inspected'),
            style: toonTitle(context, size: 15),
          ),
          const SizedBox(height: Gap.sm),
          for (final item in const ['wait', 'lite', 'nova'])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GameCard(
                key: ValueKey('shop_$item'),
                selected: _item == item,
                onTap: () => setState(() {
                  _item = item;
                  _inspected.add(item);
                }),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        PropIcon(
                          item == 'wait' ? PropKind.jar : PropKind.laptop,
                          size: 42,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('c5_opt_$item'),
                                style: toonTitle(context, size: 16),
                              ),
                              Text(
                                t('c5_opt_${item}_d'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _item == item
                              ? Icons.expand_less_rounded
                              : Icons.search_rounded,
                          color: Toon.ink,
                        ),
                      ],
                    ),
                    if (_item == item) ...[const Divider(), ..._details(item)],
                  ],
                ),
              ),
            ),
        ],
      ),
      bottom: _item == 'wait'
          ? doneButton('c5_choose_wait', result: () => _result('none'))
          : GameButton(
              key: const ValueKey('shop_choose'),
              label: t('c5_choose'),
              icon: Icons.shopping_bag_rounded,
              onPressed: _item == null
                  ? null
                  : () {
                      tapFeedback();
                      setState(() => _paying = true);
                    },
            ),
    );
  }
}

/// Chapter 5: read a credit statement and see what each way of repaying
/// really costs. A sample statement is shown when nothing was borrowed.
class StatementActivity extends ActivityWidget {
  const StatementActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<StatementActivity> createState() => _StatementState();
}

class _StatementState extends ConsumerState<StatementActivity>
    with ActivityHelpers {
  int? _answer;
  bool? _predict;
  int? _plan;
  int? _pay;
  final _seen = <int>{};

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final real = s.debt > 0;
    final owed = real ? s.debt : StoryRules.novaPrice;
    final minPay = StoryRules.minPayment(owed);
    final minPlan = StoryRules.repaySchedule(owed, minPay);
    final plans = {minPay, if (minPay * 2 < owed) minPay * 2, owed}.toList();
    final answers = {
      owed,
      owed + StoryRules.monthlyInterest(owed),
      minPlan.totalPaid,
    }.toList()..sort();
    final shown = _plan == null ? null : StoryRules.repaySchedule(owed, _plan!);
    final payOptions = StoryRules.c5PayOptions(s);

    Widget chip(String key, String label, bool selected, VoidCallback onTap) =>
        ChoiceChip(
          key: ValueKey(key),
          label: Text(label),
          selected: selected,
          onSelected: (_) {
            tapFeedback();
            onTap();
          },
        );

    return BeatLayout(
      guide: guide(
        real ? 'c5_stmt_intro' : 'c5_stmt_sample',
        who: 'imran',
        mood: Mood.neutral,
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GameCard(
            color: const Color(0xFFFFF1C9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const PropIcon(PropKind.card, size: 30),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t('c5_stmt_title'),
                        style: toonTitle(context, size: 17),
                      ),
                    ),
                    TagLabel(t(real ? 'st_pretend' : 'c5_sample')),
                  ],
                ),
                FactRow(
                  label: t('c5_owed'),
                  value: formatRupees(owed),
                  strong: true,
                ),
                FactRow(label: t('c5_due'), value: t('c5_due_value')),
                FactRow(label: t('c5_min'), value: formatRupees(minPay)),
                Text(
                  t('c5_stmt_rule'),
                  style: const TextStyle(fontSize: 13, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          Text(
            tx('c5_stmt_q', {'owed': owed, 'min': minPay}),
            style: toonTitle(context, size: 16),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < answers.length; i++)
                chip(
                  'stmt_q_$i',
                  formatRupees(answers[i]),
                  _answer == answers[i],
                  () => setState(() {
                    _predict ??= answers[i] == minPlan.totalPaid;
                    _answer = answers[i];
                  }),
                ),
            ],
          ),
          if (_answer != null) ...[
            const SizedBox(height: Gap.sm),
            ToneBanner(
              key: const ValueKey('stmt_answer'),
              tone: _answer == minPlan.totalPaid ? Tone.best : Tone.risky,
              title: t(
                _answer == minPlan.totalPaid ? 'st_correct' : 'st_think_again',
              ),
              text: tx('c5_stmt_q_why', {
                'total': minPlan.totalPaid,
                'interest': minPlan.totalInterest,
                'months': minPlan.months,
              }),
            ),
            const SizedBox(height: Gap.md),
            Text(t('c5_sim_title'), style: toonTitle(context, size: 16)),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < plans.length; i++)
                  chip(
                    'plan_$i',
                    plans[i] == owed
                        ? t('c5_plan_full')
                        : tx('c5_plan_month', {'amount': plans[i]}),
                    _plan == plans[i],
                    () => setState(() {
                      _plan = plans[i];
                      _seen.add(plans[i]);
                    }),
                  ),
              ],
            ),
            if (shown != null) ...[
              FactRow(label: t('c5_sim_months'), value: '${shown.months}'),
              FactRow(
                label: t('c5_sim_interest'),
                value: formatRupees(shown.totalInterest),
                color: shown.totalInterest > 0 ? Toon.berry : Toon.leafDark,
              ),
              FactRow(
                label: t('c5_sim_total'),
                value: formatRupees(shown.totalPaid),
                strong: true,
              ),
              // Share of the repayment that is the laptop itself; the rest
              // is the price of borrowing.
              Meter(
                value: shown.totalPaid == 0 ? 1 : owed / shown.totalPaid,
                color: Toon.teal,
              ),
              Text(
                t('c5_sim_legend'),
                style: const TextStyle(fontSize: 13, height: 1.25),
              ),
            ],
            if (real) ...[
              const SizedBox(height: Gap.md),
              Text(tx('c5_pay_now_q'), style: toonTitle(context, size: 16)),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < payOptions.length; i++)
                    chip(
                      'payopt_$i',
                      formatRupees(payOptions[i]),
                      _pay == payOptions[i],
                      () => setState(() => _pay = payOptions[i]),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
      bottom: doneButton(
        real && _pay != null ? 'c5_pay_stmt' : 'continue',
        extra: {'pay': _pay ?? 0},
        result: _answer == null || (real && _pay == null)
            ? null
            : () => {
                'pay': _pay ?? 0,
                'predict': _predict ?? false,
                'explored': _seen.length >= 2,
              },
      ),
    );
  }
}
