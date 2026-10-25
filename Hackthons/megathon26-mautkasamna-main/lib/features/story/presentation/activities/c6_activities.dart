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

/// Chapter 6: ₹2,000 in a savings account and in a fixed deposit, side by
/// side, month by month.
class CompareActivity extends ActivityWidget {
  const CompareActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<CompareActivity> createState() => _CompareActivityState();
}

class _CompareActivityState extends ConsumerState<CompareActivity>
    with ActivityHelpers {
  static const _amount = StoryRules.exampleAmount;

  int? _answer;
  bool? _predict;
  int _month = 0;
  bool _reachedEnd = false;
  String? _tried;

  void _setMonth(int m) {
    tapFeedback();
    setState(() {
      _month = m.clamp(0, StoryRules.fdMonths);
      _reachedEnd = _reachedEnd || _month == StoryRules.fdMonths;
      _tried = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fullSavings = StoryRules.simpleInterest(
      _amount,
      StoryRules.savingsRatePercent,
      StoryRules.fdMonths,
    );
    final fullFd = StoryRules.simpleInterest(
      _amount,
      StoryRules.fdRatePercent,
      StoryRules.fdMonths,
    );
    final correct = fullFd - fullSavings;
    final answers = [correct, fullFd, fullFd * 2];
    final matured = _month >= StoryRules.fdMonths;

    Widget column(String id, int rate, PropKind prop) {
      final interest = StoryRules.simpleInterest(_amount, rate, _month);
      final locked = id == 'fd' && !matured;
      return Expanded(
        child: GameCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              PropIcon(prop, size: 36),
              Text(
                t('c6_${id}_name'),
                textAlign: TextAlign.center,
                style: toonTitle(context, size: 14),
              ),
              Text(tx('c6_rate', {'rate': rate})),
              Text(
                formatRupees(_amount + interest),
                key: ValueKey('cmp_$id'),
                style: toonTitle(context, size: 20),
              ),
              Text(tx('c6_interest_so_far', {'interest': interest})),
              const SizedBox(height: 4),
              Meter(
                value: fullFd == 0 ? 0 : interest / fullFd,
                color: id == 'fd' ? Toon.clay : Toon.teal,
                height: 14,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    size: 18,
                    color: locked ? Toon.berry : Toon.leafDark,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      t(
                        locked
                            ? 'c6_locked'
                            : (id == 'fd' ? 'c6_matured' : 'c6_anytime'),
                      ),
                      style: const TextStyle(fontSize: 13, height: 1.1),
                    ),
                  ),
                ],
              ),
              TextButton(
                key: ValueKey('try_$id'),
                onPressed: () => setState(() => _tried = id),
                child: Text(t('c6_try_withdraw'), textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      );
    }

    return BeatLayout(
      guide: guide('c6_compare_intro', who: 'lakshmi', mood: Mood.happy),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tx('c6_assume', {'amount': _amount}),
            style: const TextStyle(fontSize: 13, height: 1.25),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            tx('c6_q', {'amount': _amount}),
            style: toonTitle(context, size: 16),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < answers.length; i++)
                ChoiceChip(
                  key: ValueKey('cmp_q_$i'),
                  label: Text(formatRupees(answers[i])),
                  selected: _answer == answers[i],
                  onSelected: (_) {
                    tapFeedback();
                    setState(() {
                      _predict ??= answers[i] == correct;
                      _answer = answers[i];
                    });
                  },
                ),
            ],
          ),
          if (_answer != null) ...[
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tx('c6_month_n', {'n': _month}),
                    key: const ValueKey('cmp_month'),
                    style: toonTitle(context, size: 17),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: GameButton(
                    key: const ValueKey('month_plus'),
                    label: t('c6_plus_month'),
                    style: GameButtonStyle.secondary,
                    onPressed: matured ? null : () => _setMonth(_month + 1),
                  ),
                ),
              ],
            ),
            Slider(
              value: _month.toDouble(),
              max: StoryRules.fdMonths.toDouble(),
              divisions: StoryRules.fdMonths,
              activeColor: Toon.clay,
              label: '$_month',
              onChanged: (v) => _setMonth(v.round()),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                column('sav', StoryRules.savingsRatePercent, PropKind.bank),
                const SizedBox(width: 8),
                column('fd', StoryRules.fdRatePercent, PropKind.lock),
              ],
            ),
            if (_tried != null) ...[
              const SizedBox(height: Gap.sm),
              ToneBanner(
                key: const ValueKey('try_result'),
                tone: _tried == 'fd' && !matured ? Tone.risky : Tone.best,
                title: t('c6_try_withdraw'),
                text: t(
                  _tried == 'sav'
                      ? 'c6_try_sav'
                      : (matured ? 'c6_try_fd_done' : 'c6_try_fd'),
                ),
              ),
            ],
            if (_reachedEnd) ...[
              const SizedBox(height: Gap.sm),
              ToneBanner(
                tone: _predict == true ? Tone.best : Tone.okay,
                title: t(_predict == true ? 'st_correct' : 'verdict_neutral'),
                text: tx('c6_q_why', {
                  'sav': fullSavings,
                  'fd': fullFd,
                  'diff': correct,
                }),
              ),
            ],
          ],
        ],
      ),
      bottom: doneButton(
        'continue',
        result: _answer != null && _reachedEnd
            ? () => {'predict': _predict ?? false}
            : null,
      ),
    );
  }
}

/// Chapter 6: decide how much of Asha's own money to lock away.
class FdActivity extends ActivityWidget {
  const FdActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<FdActivity> createState() => _FdActivityState();
}

class _FdActivityState extends ConsumerState<FdActivity> with ActivityHelpers {
  int? _amount;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final amount = _amount ?? 0;
    final reach = s.bank - amount;
    return BeatLayout(
      guide: guide('c6_fd_intro', who: 'asha', mood: Mood.thinking),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tx('c6_fd_q'), style: toonTitle(context, size: 16)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final option in StoryRules.c6FdOptions(s))
                ChoiceChip(
                  key: ValueKey('fd_$option'),
                  label: Text(formatRupees(option)),
                  selected: _amount == option,
                  onSelected: (_) {
                    tapFeedback();
                    setState(() => _amount = option);
                  },
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          FactRow(
            label: t('c6_reach'),
            value: formatRupees(reach),
            color: Toon.tealDark,
          ),
          Meter(value: s.bank == 0 ? 0 : reach / s.bank, color: Toon.teal),
          FactRow(
            label: t('c6_lock_amount'),
            value: formatRupees(amount),
            color: Toon.clayDark,
          ),
          const SizedBox(height: Gap.sm),
          Text(
            tx('c6_fd_proj', {
              'interest': StoryRules.simpleInterest(
                amount,
                StoryRules.fdRatePercent,
                StoryRules.fdMonths,
              ),
            }),
            key: const ValueKey('fd_projection'),
          ),
          if (_amount != null && reach < StoryRules.surpriseCost) ...[
            const SizedBox(height: Gap.sm),
            ToneBanner(
              tone: Tone.okay,
              title: t('c6_cushion_title'),
              text: t('c6_low_cushion'),
            ),
          ],
        ],
      ),
      bottom: doneButton(
        'c6_fd_btn',
        extra: {'amount': amount},
        icon: Icons.lock_rounded,
        result: _amount == null ? null : () => {'amount': _amount},
      ),
    );
  }
}

/// Chapter 6: six simulated months. Savings arrive, store credit takes its
/// share, a surprise cost lands in month three and the deposit matures.
class TimeActivity extends ActivityWidget {
  const TimeActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<TimeActivity> createState() => _TimeActivityState();
}

class _TimeActivityState extends ConsumerState<TimeActivity>
    with ActivityHelpers {
  int _month = 0;
  String? _event;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final months = StoryRules.c6Months(s, _event);
    final atEvent = _month == 3 && _event == null;
    final ended = _month >= StoryRules.fdMonths;
    final options = atEvent ? StoryRules.c6EventOptions(months[2]) : const [];
    final end = ended
        ? StoryRules.apply(s, 'c6_time', {'event': _event})
        : null;

    Widget monthCard(int m) {
      final before = m == 1 ? s : months[m - 2];
      final after = months[m - 1];
      final charged = after.interestPaid - before.interestPaid;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GameCard(
          key: ValueKey('month_$m'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tx('c6_month_n', {'n': m}),
                style: toonTitle(context, size: 16),
              ),
              FactRow(
                label: t('txn_monthly_save'),
                value: '+${formatRupees(s.monthlySave)}',
                color: Toon.leafDark,
              ),
              if (before.debt > 0) ...[
                FactRow(
                  label: t('txn_interest'),
                  value: '+${formatRupees(charged)}',
                  color: Toon.berry,
                ),
                FactRow(
                  label: t('txn_credit_pay'),
                  value: '−${formatRupees(before.debt + charged - after.debt)}',
                ),
              ],
              const Divider(),
              FactRow(
                label: t('st_bank'),
                value: formatRupees(after.bank),
                strong: true,
              ),
              if (after.fd > 0)
                FactRow(label: t('st_fd'), value: formatRupees(after.fd)),
              if (after.debt > 0)
                FactRow(label: t('st_owed'), value: formatRupees(after.debt)),
            ],
          ),
        ),
      );
    }

    return BeatLayout(
      guide: guide(
        atEvent
            ? 'c6_event_intro'
            : ended
            ? 'c6_time_end'
            : 'c6_time_intro',
        who: atEvent ? 'ravi' : 'gullu',
        mood: atEvent ? Mood.worried : Mood.happy,
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (end != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GameCard(
                key: const ValueKey('maturity_card'),
                color: const Color(0xFFDDF3D6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t('c6_six_done'), style: toonTitle(context, size: 17)),
                    FactRow(
                      label: t('txn_fd_mature'),
                      value: '+${formatRupees(end.n('c6_fd_interest'))}',
                    ),
                    FactRow(
                      label: t('txn_savings_interest'),
                      value: '+${formatRupees(end.n('c6_sav_interest'))}',
                    ),
                    if (s.n('c6_owe') == 0 && end.n('c6_owe') > 0)
                      FactRow(
                        label: t('txn_repay_amma'),
                        value: '−${formatRupees(end.n('c6_owe'))}',
                      ),
                    FactRow(
                      label: t('st_bank'),
                      value: formatRupees(end.bank),
                      strong: true,
                    ),
                  ],
                ),
              ),
            ),
          if (_event != null && _month == 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ToneBanner(
                key: const ValueKey('event_result'),
                tone: _event == 'savings' ? Tone.best : Tone.okay,
                title: t('verdict_neutral'),
                text: tx('c6_evt_${_event}_r'),
              ),
            ),
          if (atEvent) ...[
            GameCard(
              color: const Color(0xFFFFF1C9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t('c6_event_title'),
                    style: toonTitle(context, size: 17),
                  ),
                  Text(tx('c6_event_body', {'cost': StoryRules.surpriseCost})),
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (final (id, prop) in const [
              ('savings', PropKind.bank),
              ('break', PropKind.lock),
              ('family', PropKind.gift),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Opacity(
                  opacity: options.contains(id) ? 1 : 0.45,
                  child: ChoiceTile(
                    key: ValueKey('evt_$id'),
                    prop: prop,
                    label: t(
                      options.contains(id) ? 'c6_evt_$id' : 'c6_evt_${id}_no',
                    ),
                    selected: false,
                    onTap: () {
                      if (!options.contains(id)) return;
                      successFeedback();
                      setState(() => _event = id);
                    },
                  ),
                ),
              ),
          ],
          if (_month == 0)
            Text(tx('c6_time_start'), style: const TextStyle(height: 1.3)),
          for (var m = _month; m >= 1; m--) monthCard(m),
        ],
      ),
      bottom: ended
          ? doneButton('continue', result: () => {'event': _event})
          : GameButton(
              key: const ValueKey('next_month'),
              label: t('c6_next_month'),
              icon: Icons.skip_next_rounded,
              onPressed: atEvent
                  ? null
                  : () {
                      tapFeedback();
                      setState(() => _month++);
                    },
            ),
    );
  }
}
