import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/game/characters.dart';
import '../../../../core/game/game_style.dart';
import '../../../../core/game/game_widgets.dart';
import '../../../../core/game/props.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/story_rules.dart';
import '../story_widgets.dart';
import 'activity_base.dart';

/// The pretend bank's balance card.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.bankName,
    required this.tag,
    required this.label,
    required this.balance,
    this.footer,
  });

  final String bankName;
  final String tag;
  final String label;
  final int balance;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: toonPanel(color: Toon.teal, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PropIcon(PropKind.bank, size: 30),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bankName,
                  style: toonTitle(context, size: 15, color: Colors.white),
                ),
              ),
              TagLabel(tag),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
          Semantics(
            label: '$label: ${formatRupees(balance)}',
            excludeSemantics: true,
            child: TweenAnimationBuilder<int>(
              tween: IntTween(end: balance),
              duration: motionEnabled(context)
                  ? const Duration(milliseconds: 600)
                  : Duration.zero,
              builder: (context, v, _) => Text(
                formatRupees(v),
                key: const ValueKey('bank_balance'),
                style: toonTitle(context, size: 30, color: Colors.white),
              ),
            ),
          ),
          ?footer,
        ],
      ),
    );
  }
}

class _Entry {
  const _Entry(this.label, this.amount, this.balance, {this.pending = false});

  final String label;
  final int amount;
  final int balance;
  final bool pending;
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.label,
    this.status,
    this.hideBalance = false,
  });

  final _Entry entry;
  final String label;
  final String? status;
  final bool hideBalance;

  @override
  Widget build(BuildContext context) {
    final incoming = entry.amount >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            entry.pending
                ? Icons.hourglass_top_rounded
                : incoming
                ? Icons.south_west_rounded
                : Icons.north_east_rounded,
            size: 20,
            color: entry.pending
                ? GullakColors.caution
                : incoming
                ? Toon.leafDark
                : Toon.berry,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(height: 1.2)),
                if (status != null)
                  Text(
                    status!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Toon.clayDark,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${incoming ? '+' : '−'}${formatRupees(entry.amount.abs())}',
                style: toonTitle(context, size: 15),
              ),
              Text(
                hideBalance ? '₹ ?' : formatRupees(entry.balance),
                style: const TextStyle(fontSize: 12, height: 1.1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chapter 3: open the student account by moving the gullak into the bank.
class OpenAccountActivity extends ActivityWidget {
  const OpenAccountActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<OpenAccountActivity> createState() => _OpenAccountState();
}

class _OpenAccountState extends ConsumerState<OpenAccountActivity>
    with ActivityHelpers {
  late bool _jarIn = widget.s.jar == 0;
  bool _giftIn = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final balance =
        (_jarIn ? s.jar : 0) + (_giftIn ? StoryRules.openingGift : 0);
    return BeatLayout(
      guide: guide('c3_open_intro', who: 'lakshmi', mood: Mood.happy),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BalanceCard(
            bankName: t('c3_bank_name'),
            tag: t('st_pretend'),
            label: t('c3_account_type'),
            balance: balance,
          ),
          const SizedBox(height: Gap.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              JarView(fill: _jarIn ? 0 : 0.8, size: 84),
              const Icon(Icons.arrow_forward_rounded, size: 36),
              const PropIcon(PropKind.bank, size: 76),
            ],
          ),
          const SizedBox(height: Gap.md),
          Opacity(
            opacity: _jarIn ? 0.5 : 1,
            child: GameCard(
              key: const ValueKey('open_jar'),
              onTap: _jarIn ? null : () => setState(() => _jarIn = true),
              child: Row(
                children: [
                  const PropIcon(PropKind.jar, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tx('c3_open_jar'),
                      style: toonTitle(context, size: 16),
                    ),
                  ),
                  if (_jarIn)
                    const Icon(Icons.check_circle, color: Toon.leafDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: _giftIn || !_jarIn ? 0.5 : 1,
            child: GameCard(
              key: const ValueKey('open_gift'),
              onTap: _giftIn || !_jarIn
                  ? null
                  : () => setState(() => _giftIn = true),
              child: Row(
                children: [
                  const PropIcon(PropKind.gift, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tx('c3_open_gift'),
                      style: toonTitle(context, size: 16),
                    ),
                  ),
                  if (_giftIn)
                    const Icon(Icons.check_circle, color: Toon.leafDark),
                ],
              ),
            ),
          ),
        ],
      ),
      bottom: doneButton(
        'continue',
        result: _jarIn && _giftIn ? () => const {} : null,
      ),
    );
  }
}

/// Chapter 3: a working pretend banking app. Deposit, withdraw and pay by
/// UPI, then check the passbook.
class BankActivity extends ActivityWidget {
  const BankActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<BankActivity> createState() => _BankActivityState();
}

class _BankActivityState extends ConsumerState<BankActivity>
    with ActivityHelpers {
  static const _tasks = {
    'deposit': StoryRules.depositAmount,
    'withdraw': StoryRules.withdrawAmount,
    'upi': StoryRules.upiAmount,
  };

  final _done = <String>{};
  final _history = <_Entry>[];
  late int _bank = widget.s.bank;
  late int _wallet = widget.s.wallet;
  String? _action;
  int? _amount;
  String? _payee;
  bool _processing = false;
  int _slips = 0;
  String? _hint;
  int? _answer;
  bool? _predict;

  bool get _tasksDone => _done.length == _tasks.length;

  Future<void> _confirm() async {
    final action = _action;
    final amount = _amount;
    if (action == null || amount == null || _processing) return;
    String? hint;
    if (_done.contains(action)) {
      hint = 'c3_hint_done';
    } else if (_tasks[action] != amount) {
      hint = 'c3_hint_amount';
    } else if (action == 'upi' && _payee != 'imran') {
      hint = 'c3_hint_payee';
    }
    if (hint != null) {
      warnFeedback();
      setState(() {
        _slips++;
        _hint = hint;
      });
      return;
    }
    setState(() {
      _processing = true;
      _hint = null;
    });
    await pause(700);
    if (!mounted) return;
    successFeedback();
    setState(() {
      switch (action) {
        case 'deposit':
          _wallet -= amount;
          _bank += amount;
          _history.add(_Entry('txn_deposit', amount, _bank));
        case 'withdraw':
          _bank -= amount;
          _wallet += amount;
          _history.add(_Entry('txn_withdraw', -amount, _bank));
        default:
          _bank -= amount;
          _history.add(_Entry('txn_upi_shop', -amount, _bank));
      }
      _done.add(action);
      _processing = false;
      _action = null;
      _amount = null;
      _payee = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.s.bank;
    final correct = start + 300 - 200 - 150;
    final options = [
      if (start >= 350) start - 350 else 0,
      correct,
      start + 100,
    ];

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
        _tasksDone ? 'c3_check_intro' : 'c3_bank_intro',
        who: 'lakshmi',
        mood: _tasksDone ? Mood.thinking : Mood.happy,
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_tasksDone)
            _BalanceCard(
              bankName: t('c3_bank_name'),
              tag: t('st_pretend'),
              label: t('c3_balance'),
              balance: _bank,
              footer: Text(
                tx('c3_cash_in_hand', {'cash': _wallet}),
                key: const ValueKey('bank_cash'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          if (!_tasksDone) ...[
            const SizedBox(height: Gap.sm),
            for (final task in _tasks.keys)
              Row(
                children: [
                  Icon(
                    _done.contains(task)
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: _done.contains(task) ? Toon.leafDark : Toon.ink,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t('c3_task_$task'))),
                ],
              ),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                for (final (action, icon) in const [
                  ('deposit', Icons.south_west_rounded),
                  ('withdraw', Icons.north_east_rounded),
                  ('upi', Icons.qr_code_2_rounded),
                ]) ...[
                  Expanded(
                    child: GameCard(
                      key: ValueKey('act_$action'),
                      selected: _action == action,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      onTap: _processing
                          ? null
                          : () => setState(() {
                              _action = action;
                              _hint = null;
                            }),
                      child: Column(
                        children: [
                          Icon(icon, color: Toon.ink),
                          Text(
                            t('c3_act_$action'),
                            textAlign: TextAlign.center,
                            style: toonTitle(context, size: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (action != 'upi') const SizedBox(width: 8),
                ],
              ],
            ),
            if (_action != null) ...[
              const SizedBox(height: Gap.sm),
              GameCard(
                color: const Color(0xFFEAF6FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t('c3_pick_amount'),
                      style: toonTitle(context, size: 15),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final amount in const [150, 200, 300])
                          chip(
                            'amt_$amount',
                            formatRupees(amount),
                            _amount == amount,
                            () => setState(() => _amount = amount),
                          ),
                      ],
                    ),
                    if (_action == 'upi') ...[
                      Text(
                        t('c3_pick_payee'),
                        style: toonTitle(context, size: 15),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final payee in const ['unknown', 'imran'])
                            chip(
                              'payee_$payee',
                              t('c3_payee_$payee'),
                              _payee == payee,
                              () => setState(() => _payee = payee),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const PropIcon(PropKind.lock, size: 26),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t('c3_pin_note'),
                              style: const TextStyle(fontSize: 13, height: 1.2),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    GameButton(
                      key: const ValueKey('bank_confirm'),
                      label: t('c3_confirm'),
                      style: GameButtonStyle.secondary,
                      busy: _processing,
                      onPressed:
                          _amount == null ||
                              (_action == 'upi' && _payee == null)
                          ? null
                          : _confirm,
                    ),
                  ],
                ),
              ),
            ],
            if (_hint != null) ...[
              const SizedBox(height: Gap.sm),
              ToneBanner(
                key: const ValueKey('bank_hint'),
                tone: Tone.risky,
                title: t('st_think_again'),
                text: t(_hint!),
              ),
            ],
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(t('c3_history'), style: toonTitle(context, size: 16)),
            _EntryRow(
              entry: _Entry('c3_opening', start, start),
              label: t('c3_opening'),
            ),
            for (var i = 0; i < _history.length; i++)
              _EntryRow(
                entry: _history[i],
                label: t(_history[i].label),
                hideBalance:
                    _tasksDone && _answer == null && i == _history.length - 1,
              ),
          ],
          if (_tasksDone) ...[
            const SizedBox(height: Gap.sm),
            Text(t('c3_check_q'), style: toonTitle(context, size: 16)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < options.length; i++)
                  chip(
                    'check_$i',
                    formatRupees(options[i]),
                    _answer == options[i],
                    () => setState(() {
                      _predict ??= options[i] == correct;
                      _answer = options[i];
                    }),
                  ),
              ],
            ),
            if (_answer != null) ...[
              const SizedBox(height: Gap.sm),
              ToneBanner(
                key: const ValueKey('check_result'),
                tone: _answer == correct ? Tone.best : Tone.risky,
                title: t(_answer == correct ? 'st_correct' : 'st_think_again'),
                text: tx('c3_check_why', {'start': start, 'end': correct}),
              ),
            ],
          ],
        ],
      ),
      bottom: doneButton(
        'continue',
        result: _tasksDone && _answer == correct
            ? () => {'slips': _slips, 'predict': _predict ?? false}
            : null,
      ),
    );
  }
}

/// Chapter 3: a UPI payment gets stuck on "pending". What now?
class PendingActivity extends ActivityWidget {
  const PendingActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<PendingActivity> createState() => _PendingActivityState();
}

class _PendingActivityState extends ConsumerState<PendingActivity>
    with ActivityHelpers {
  /// pay → pending → history → detail → verify | double | cash
  String _phase = 'pay';
  bool _processing = false;

  bool get _resolved => const ['verify', 'double', 'cash'].contains(_phase);

  Future<void> _go(String phase, {int wait = 0}) async {
    if (_processing) return;
    if (wait > 0) {
      setState(() => _processing = true);
      await pause(wait);
      if (!mounted) return;
    }
    phase == 'verify' ? successFeedback() : tapFeedback();
    setState(() {
      _processing = false;
      _phase = phase;
    });
  }

  @override
  Widget build(BuildContext context) {
    const fee = StoryRules.fairFee;
    final bank = widget.s.bank;
    final pendingEntry = _Entry(
      'txn_fair_fee',
      -fee,
      bank - fee,
      pending: true,
    );

    Widget option(
      String key,
      String label,
      IconData icon,
      VoidCallback onTap,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GameCard(
        key: ValueKey(key),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: Toon.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Text(t(label), style: toonTitle(context, size: 16)),
            ),
          ],
        ),
      ),
    );

    final List<Widget> body = switch (_phase) {
      'pay' => [
        GameCard(
          child: Column(
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 56, color: Toon.ink),
              Text(t('c3_fair_desk'), style: toonTitle(context, size: 18)),
              Text(formatRupees(fee), style: toonTitle(context, size: 26)),
              const SizedBox(height: 6),
              GameButton(
                key: const ValueKey('pay_fee'),
                label: t('c3_pay_fee'),
                style: GameButtonStyle.secondary,
                busy: _processing,
                onPressed: () => _go('pending', wait: 900),
              ),
            ],
          ),
        ),
      ],
      'pending' => [
        GameCard(
          key: const ValueKey('pending_card'),
          color: const Color(0xFFFFF1C9),
          child: Column(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 44,
                color: GullakColors.caution,
              ),
              Text(t('c3_pending_title'), style: toonTitle(context, size: 19)),
              Text(t('c3_pending_body'), textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        option(
          'pend_history',
          'c3_pend_history',
          Icons.receipt_long_rounded,
          () => _go('history'),
        ),
        option(
          'pend_again',
          'c3_pend_again',
          Icons.replay_rounded,
          () => _go('double', wait: 700),
        ),
        option(
          'pend_cash',
          'c3_pend_cash',
          Icons.payments_rounded,
          () => _go('cash', wait: 400),
        ),
      ],
      'history' => [
        Text(t('c3_history'), style: toonTitle(context, size: 16)),
        Text(t('c3_history_tap')),
        const SizedBox(height: 6),
        GameCard(
          key: const ValueKey('pend_row'),
          onTap: () => _go('detail'),
          child: _EntryRow(
            entry: pendingEntry,
            label: t('txn_fair_fee'),
            status: t('c3_status_pending'),
          ),
        ),
      ],
      'detail' => [
        GameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EntryRow(
                entry: pendingEntry,
                label: t('txn_fair_fee'),
                status: t('c3_status_pending'),
              ),
              const Divider(),
              Text(t('c3_detail'), style: const TextStyle(height: 1.3)),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        option(
          'pend_refresh',
          'c3_pend_refresh',
          Icons.refresh_rounded,
          () => _go('verify', wait: 900),
        ),
        option(
          'pend_again',
          'c3_pend_again',
          Icons.replay_rounded,
          () => _go('double', wait: 700),
        ),
      ],
      _ => [
        ToneBanner(
          key: const ValueKey('pending_result'),
          tone: _phase == 'verify' ? Tone.best : Tone.risky,
          title: t(_phase == 'verify' ? 'c3_status_success' : 'c3_paid_twice'),
          text: tx('c3_res_$_phase'),
        ),
        const SizedBox(height: Gap.md),
        GameCard(
          child: Column(
            children: [
              _EntryRow(
                entry: _Entry('txn_fair_fee', -fee, bank - fee),
                label: t('txn_fair_fee'),
                status: t('c3_status_success'),
              ),
              if (_phase == 'double')
                _EntryRow(
                  entry: _Entry('txn_fair_fee_again', -fee, bank - 2 * fee),
                  label: t('txn_fair_fee_again'),
                  status: t('c3_status_success'),
                ),
              if (_phase != 'verify')
                FactRow(
                  label: t('txn_fee_refund'),
                  value: '+${formatRupees(fee)}',
                  color: Toon.leafDark,
                ),
            ],
          ),
        ),
      ],
    };

    return BeatLayout(
      guide: guide(
        _resolved
            ? 'c3_pending_after'
            : _phase == 'pay'
            ? 'c3_pending_intro'
            : 'c3_pending_think',
        who: 'asha',
        mood: _resolved
            ? (_phase == 'verify' ? Mood.cheer : Mood.surprised)
            : _phase == 'pay'
            ? Mood.happy
            : Mood.worried,
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: body,
      ),
      bottom: doneButton(
        'continue',
        result: _resolved ? () => {'path': _phase} : null,
      ),
    );
  }
}
