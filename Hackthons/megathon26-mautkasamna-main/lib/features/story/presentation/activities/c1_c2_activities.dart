import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/game/characters.dart';
import '../../../../core/game/effects.dart';
import '../../../../core/game/game_style.dart';
import '../../../../core/game/game_tokens.dart';
import '../../../../core/game/game_widgets.dart';
import '../../../../core/game/props.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/story_rules.dart';
import '../story_widgets.dart';
import 'activity_base.dart';

/// Chapter 1: plan the week by adding and removing expenses on Asha's desk.
class BudgetActivity extends ActivityWidget {
  const BudgetActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<BudgetActivity> createState() => _BudgetActivityState();
}

class _BudgetActivityState extends ConsumerState<BudgetActivity>
    with ActivityHelpers {
  final _picked = <String>{};
  int _tries = 0;
  String? _problem;

  void _toggle(String id) {
    tapFeedback();
    setState(() {
      if (!_picked.remove(id)) _picked.add(id);
      _problem = null;
    });
  }

  void _submit() {
    final budget = widget.s.wallet;
    final total = StoryRules.c1Total(_picked);
    final missing = StoryRules.c1MissingNeeds(_picked);
    String? problem;
    if (total > budget) {
      problem = tx('c1_over', {'over': total - budget});
    } else if (missing.isNotEmpty) {
      problem = tx('c1_missing_${missing.first}');
    }
    if (problem != null) {
      warnFeedback();
      setState(() {
        _tries++;
        _problem = problem;
      });
      return;
    }
    successFeedback();
    widget.onDone({'items': _picked.toList(), 'tries': _tries});
  }

  @override
  Widget build(BuildContext context) {
    final budget = widget.s.wallet;
    final total = StoryRules.c1Total(_picked);
    final left = budget - total;
    return BeatLayout(
      guide: guide(
        'c1_budget_intro',
        mood: left < 0 ? Mood.worried : Mood.happy,
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WalletMeter(total: total, budget: budget),
          const SizedBox(height: Gap.md),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 330 ? 3 : 2;
              final width = (box.maxWidth - 10 * (columns - 1)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 12,
                children: [
                  for (final item in StoryRules.c1Items)
                    SizedBox(
                      width: width,
                      child: ItemToken(
                        key: ValueKey('item_${item.id}'),
                        label: t('exp_${item.id}'),
                        cost: item.cost,
                        prop: PropKind.parse(item.prop),
                        selected: _picked.contains(item.id),
                        onTap: () => _toggle(item.id),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: Gap.md),
          GameCard(
            color: const Color(0xFFFFF1C9),
            child: Row(
              children: [
                JarView(fill: left <= 0 ? 0 : left / 400, size: 64),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    left >= 0
                        ? tx('c1_to_jar', {'left': left})
                        : tx('c1_short', {'over': -left}),
                    key: const ValueKey('budget_left'),
                    style: toonTitle(context, size: 16),
                  ),
                ),
              ],
            ),
          ),
          if (_problem != null) ...[
            const SizedBox(height: Gap.md),
            ToneBanner(
              key: const ValueKey('budget_problem'),
              tone: Tone.risky,
              title: t('st_think_again'),
              text: _problem!,
            ),
          ],
        ],
      ),
      bottom: GameButton(
        key: const ValueKey('budget_submit'),
        label: t('c1_lock_plan'),
        icon: Icons.lock_rounded,
        busy: widget.busy,
        onPressed: _picked.isEmpty ? null : _submit,
      ),
    );
  }
}

/// Chapter 2: choose a first savings target and see how long it takes.
class GoalActivity extends ActivityWidget {
  const GoalActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<GoalActivity> createState() => _GoalActivityState();
}

class _GoalActivityState extends ConsumerState<GoalActivity>
    with ActivityHelpers {
  String? _goal;
  int _weekly = 200;

  @override
  Widget build(BuildContext context) {
    return BeatLayout(
      guide: guide('c2_goal_intro', who: 'asha', mood: Mood.thinking),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tx('c2_goal_try'), style: toonTitle(context, size: 15)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final amount in const [100, 200, 300])
                ChoiceChip(
                  key: ValueKey('weekly_$amount'),
                  label: Text(formatRupees(amount)),
                  selected: _weekly == amount,
                  onSelected: (_) {
                    tapFeedback();
                    setState(() => _weekly = amount);
                  },
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          for (final goal in StoryRules.goals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GameCard(
                key: ValueKey('goal_${goal.id}'),
                selected: _goal == goal.id,
                onTap: () => setState(() => _goal = goal.id),
                child: Row(
                  children: [
                    PropIcon(PropKind.parse(goal.prop), size: 46),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('goal_${goal.id}'),
                            style: toonTitle(context, size: 16),
                          ),
                          Text(
                            tx('c2_goal_eta', {
                              'weeks':
                                  StoryRules.weeksToGoal(
                                    goal.target,
                                    widget.s.jar,
                                    _weekly,
                                  ) ??
                                  0,
                              'weekly': _weekly,
                            }),
                            style: const TextStyle(fontSize: 14, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formatRupees(goal.target),
                      style: toonTitle(context, size: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottom: doneButton(
        'c2_goal_set',
        result: _goal == null ? null : () => {'goal': _goal},
      ),
    );
  }
}

/// Chapter 2: one week of deciding how much goes into the gullak.
class SaveWeekActivity extends ActivityWidget {
  const SaveWeekActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
    required this.week,
  });

  final int week;

  @override
  ConsumerState<SaveWeekActivity> createState() => _SaveWeekActivityState();
}

class _SaveWeekActivityState extends ConsumerState<SaveWeekActivity>
    with ActivityHelpers {
  late final int _income = StoryRules.c2Income(widget.s, widget.week);
  late int _save = _income >= 100 ? 100 : 0;
  bool _dropped = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final target = s.goalTarget == 0 ? 1000 : s.goalTarget;
    final jar = s.jar + _save;
    final weeks = StoryRules.weeksToGoal(target, jar, _save);
    final note = switch (widget.week) {
      1 when s.n('c1_advance') > 0 => 'c2_note_advance',
      2 when _income < StoryRules.weeklyMoney => 'c2_note_treat',
      3 => 'c2_note_lab',
      _ => null,
    };
    return Stack(
      children: [
        BeatLayout(
          guide: guide(
            'c2_week_intro',
            mood: _save == 0 ? Mood.worried : Mood.happy,
            extra: {'n': widget.week, 'income': _income},
          ),
          panel: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  JarView(fill: jar / target),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TagLabel(tx('c2_week_n', {'n': widget.week})),
                        const SizedBox(height: 4),
                        Text(
                          tx('c2_jar_now', {'amount': jar}),
                          key: const ValueKey('jar_preview'),
                          style: toonTitle(context, size: 18),
                        ),
                        Text(
                          tx('c2_goal_left', {
                            'left': target > jar ? target - jar : 0,
                            'goal': t('goal_${s.goalId ?? 'kit'}'),
                          }),
                          style: const TextStyle(fontSize: 14, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Meter(value: jar / target),
              const SizedBox(height: 4),
              Text(
                weeks == null
                    ? t('c2_eta_never')
                    : weeks == 0
                    ? t('c2_eta_reached')
                    : tx('c2_eta', {'weeks': weeks, 'weekly': _save}),
                key: const ValueKey('goal_eta'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (note != null) ...[
                const SizedBox(height: Gap.sm),
                Text(
                  tx(note, {'cost': StoryRules.weeklyMoney - _income}),
                  style: const TextStyle(color: Toon.clayDark),
                ),
              ],
              const SizedBox(height: Gap.sm),
              AmountStepper(
                value: _save,
                max: _income,
                step: 10,
                label: t('c2_to_jar'),
                onChanged: (v) => setState(() => _save = v),
              ),
              FactRow(label: t('c2_to_jar'), value: formatRupees(_save)),
              FactRow(
                label: t('c2_to_spend'),
                value: formatRupees(_income - _save),
              ),
            ],
          ),
          bottom: doneButton(
            'c2_save_btn',
            extra: {'save': _save},
            icon: Icons.savings_rounded,
            result: () {
              setState(() => _dropped = true);
              return {'save': _save};
            },
          ),
        ),
        if (_dropped && _save > 0)
          const Positioned.fill(
            child: CoinBurst(
              from: Alignment(0, 0.9),
              to: Alignment(-0.6, -0.2),
              count: 6,
            ),
          ),
      ],
    );
  }
}
