import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/game/characters.dart';
import '../../../../core/game/game_style.dart';
import '../../../../core/game/props.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/story_rules.dart';
import '../story_widgets.dart';
import 'activity_base.dart';

/// Chapter 7: read the family's pretend health policy, then judge what it
/// actually pays.
class PolicyActivity extends ActivityWidget {
  const PolicyActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<PolicyActivity> createState() => _PolicyActivityState();
}

class _PolicyActivityState extends ConsumerState<PolicyActivity>
    with ActivityHelpers {
  static const _sections = [
    ('premium', Icons.payments_rounded),
    ('limit', Icons.vertical_align_top_rounded),
    ('deductible', Icons.content_cut_rounded),
    ('exclusions', Icons.block_rounded),
    ('covered', Icons.check_circle_outline_rounded),
    ('excluded', Icons.cancel_outlined),
  ];
  static const _needed = 4;

  final _read = <String>{};
  String? _open;
  bool? _claim;
  int? _calc;
  bool? _calcRight;

  @override
  Widget build(BuildContext context) {
    final pays = StoryRules.policyPays(
      StoryRules.hospitalExample,
      hospitalStay: true,
    );
    final answers = [StoryRules.hospitalExample, pays, 0];
    final unlocked = _read.length >= _needed;
    return BeatLayout(
      guide: guide(
        _claim == null ? 'c7_policy_intro' : 'c7_policy_q2_intro',
        mood: Mood.thinking,
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PropIcon(PropKind.document, size: 34),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t('c7_policy_name'),
                  style: toonTitle(context, size: 17),
                ),
              ),
              TagLabel(t('st_pretend')),
            ],
          ),
          Text(
            tx('c7_read_count', {'n': _read.length, 'total': _sections.length}),
            key: const ValueKey('policy_read'),
          ),
          const SizedBox(height: Gap.sm),
          for (final (id, icon) in _sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GameCard(
                key: ValueKey('pol_$id'),
                selected: _open == id,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                onTap: () => setState(() {
                  _open = _open == id ? null : id;
                  _read.add(id);
                }),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: Toon.ink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t('c7_pol_$id'),
                            style: toonTitle(context, size: 15),
                          ),
                        ),
                        if (_read.contains(id))
                          const Icon(
                            Icons.done_rounded,
                            size: 20,
                            color: Toon.leafDark,
                          ),
                      ],
                    ),
                    if (_open == id)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          tx('c7_pol_${id}_b'),
                          style: const TextStyle(height: 1.3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Gap.sm),
          if (!unlocked)
            Text(
              tx('c7_read_more', {'n': _needed}),
              style: const TextStyle(fontWeight: FontWeight.w700),
            )
          else ...[
            Text(tx('c7_q1'), style: toonTitle(context, size: 16)),
            const SizedBox(height: 6),
            if (_claim == null)
              Row(
                children: [
                  Expanded(
                    child: GameCard(
                      key: const ValueKey('claim_yes'),
                      onTap: () => setState(() => _claim = true),
                      child: Text(
                        t('c7_q1_yes'),
                        textAlign: TextAlign.center,
                        style: toonTitle(context, size: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GameCard(
                      key: const ValueKey('claim_no'),
                      onTap: () => setState(() => _claim = false),
                      child: Text(
                        t('c7_q1_no'),
                        textAlign: TextAlign.center,
                        style: toonTitle(context, size: 15),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              ToneBanner(
                key: const ValueKey('claim_result'),
                tone: _claim! ? Tone.risky : Tone.best,
                title: t(_claim! ? 'c7_claim_rejected' : 'st_correct'),
                text: tx(_claim! ? 'c7_q1_yes_r' : 'c7_q1_no_r'),
              ),
              const SizedBox(height: Gap.md),
              Text(
                tx('c7_q2', {'bill': StoryRules.hospitalExample}),
                style: toonTitle(context, size: 16),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < answers.length; i++)
                    ChoiceChip(
                      key: ValueKey('calc_$i'),
                      label: Text(formatRupees(answers[i])),
                      selected: _calc == answers[i],
                      onSelected: (_) {
                        tapFeedback();
                        setState(() {
                          _calcRight ??= answers[i] == pays;
                          _calc = answers[i];
                        });
                      },
                    ),
                ],
              ),
              if (_calc != null) ...[
                const SizedBox(height: Gap.sm),
                ToneBanner(
                  key: const ValueKey('calc_result'),
                  tone: _calc == pays ? Tone.best : Tone.risky,
                  title: t(_calc == pays ? 'st_correct' : 'st_think_again'),
                  text: tx('c7_q2_why', {
                    'bill': StoryRules.hospitalExample,
                    'pays': pays,
                    'own': StoryRules.deductible,
                  }),
                ),
              ],
            ],
          ],
        ],
      ),
      bottom: doneButton(
        'continue',
        result: _claim == null || _calc == null
            ? null
            : () => {'claim': _claim, 'calc': _calcRight ?? false},
      ),
    );
  }
}

/// Chapter 7: rebuild the month's household plan so the ₹1,000 clinic bill
/// is covered without cutting essentials.
class PlanActivity extends ActivityWidget {
  const PlanActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<PlanActivity> createState() => _PlanActivityState();
}

class _PlanActivityState extends ConsumerState<PlanActivity>
    with ActivityHelpers {
  final _on = <String>{};
  int _asha = 0;
  int _tries = 0;
  String? _warning;

  static const _sources = [
    ('fund', StoryRules.familyFund, PropKind.jar, false),
    ('eatOut', StoryRules.eatOutCut, PropKind.samosa, false),
    ('tv', StoryRules.tvCut, PropKind.tv, false),
    ('uncle', StoryRules.uncleLoan, PropKind.gift, false),
    ('power', 300, PropKind.bulb, true),
    ('food', 400, PropKind.tiffin, true),
  ];

  void _toggle(String id, bool essential) {
    if (essential) {
      warnFeedback();
      setState(() {
        _tries++;
        _warning = 'c7_warn_$id';
      });
      return;
    }
    tapFeedback();
    setState(() {
      if (!_on.remove(id)) _on.add(id);
      _warning = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = StoryRules.c7PlanTotal(
      fund: _on.contains('fund'),
      eatOut: _on.contains('eatOut'),
      tv: _on.contains('tv'),
      uncle: _on.contains('uncle'),
      asha: _asha,
    );
    const bill = StoryRules.clinicBill;
    final covered = total >= bill;
    final ashaMax = StoryRules.c7AshaMax(widget.s);
    return BeatLayout(
      guide: guide(
        covered ? 'c7_plan_ready' : 'c7_plan_intro',
        who: 'amma',
        mood: covered ? Mood.happy : Mood.worried,
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PropIcon(PropKind.medkit, size: 34),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tx('c7_covered', {'total': total, 'bill': bill}),
                  key: const ValueKey('plan_total'),
                  style: toonTitle(context, size: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Meter(value: total / bill, color: covered ? Toon.leaf : Toon.gold),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                covered ? Icons.check_circle_outline : Icons.hourglass_bottom,
                size: 18,
                color: covered ? Toon.leafDark : Toon.clayDark,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  covered
                      ? (total > bill
                            ? tx('c7_extra', {'extra': total - bill})
                            : t('c7_exact'))
                      : tx('c7_still_need', {'need': bill - total}),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          for (final (id, amount, prop, essential) in _sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GameCard(
                key: ValueKey('src_$id'),
                selected: _on.contains(id),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                onTap: () => _toggle(id, essential),
                child: Row(
                  children: [
                    PropIcon(prop, size: 36),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('c7_src_$id'),
                            style: toonTitle(context, size: 15),
                          ),
                          Text(
                            t('c7_src_${id}_d'),
                            style: const TextStyle(fontSize: 13, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      children: [
                        Text(
                          formatRupees(amount),
                          style: toonTitle(context, size: 16),
                        ),
                        Icon(
                          _on.contains(id)
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color: _on.contains(id) ? Toon.leafDark : Toon.ink,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_warning != null) ...[
            ToneBanner(
              key: const ValueKey('plan_warning'),
              tone: Tone.risky,
              title: t('c7_warn_title'),
              text: t(_warning!),
            ),
            const SizedBox(height: Gap.sm),
          ],
          GameCard(
            color: const Color(0xFFEAF6FF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tx('c7_src_asha', {'max': ashaMax}),
                  style: toonTitle(context, size: 15),
                ),
                Text(
                  t('c7_src_asha_d'),
                  style: const TextStyle(fontSize: 13, height: 1.2),
                ),
                AmountStepper(
                  value: _asha,
                  max: ashaMax,
                  step: 100,
                  label: t('c7_src_asha_d'),
                  onChanged: (v) => setState(() => _asha = v),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: doneButton(
        'c7_pay_bill',
        icon: Icons.local_hospital_rounded,
        result: covered
            ? () => {
                'fund': _on.contains('fund'),
                'eatOut': _on.contains('eatOut'),
                'tv': _on.contains('tv'),
                'uncle': _on.contains('uncle'),
                'asha': _asha,
                'tries': _tries,
              }
            : null,
      ),
    );
  }
}
