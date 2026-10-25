import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/game/characters.dart';
import '../../../../core/game/game_style.dart';
import '../../../../core/game/game_tokens.dart';
import '../../../../core/game/game_widgets.dart';
import '../../../../core/game/props.dart';
import '../../domain/story_rules.dart';
import '../story_widgets.dart';
import 'activity_base.dart';

/// A pretend message. Text lives in the story strings as
/// `c4_<id>_s<n>`; [clues] lists which of its four parts are warning signs
/// (explained by `c4_<id>_k<n>`).
class _Message {
  const _Message(this.id, this.clues);

  final String id;
  final Set<int> clues;
}

const _messages = [
  _Message('m1', {0, 1, 2}),
  _Message('m2', {0, 1, 2}),
  _Message('m3', {1, 2, 3}),
  _Message('m4', {0, 1, 2}),
];

/// Chapter 4: investigate four messages. Tap the parts that look wrong,
/// then decide what Asha does. Nothing is explained until she commits.
class InboxActivity extends ActivityWidget {
  const InboxActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<InboxActivity> createState() => _InboxActivityState();
}

class _InboxActivityState extends ConsumerState<InboxActivity>
    with ActivityHelpers {
  String? _open;
  final _found = <String, Set<int>>{};
  final _decisions = <String, String>{};
  int _hints = 0;
  bool _miss = false;

  int get _cluesFound => _found.values.fold(0, (sum, f) => sum + f.length);

  void _tapSegment(_Message m, int index) {
    if (_decisions.containsKey(m.id)) return;
    if (m.clues.contains(index)) {
      successFeedback();
      setState(() {
        (_found[m.id] ??= {}).add(index);
        _miss = false;
      });
    } else {
      tapFeedback();
      setState(() => _miss = true);
    }
  }

  void _hint(_Message m) {
    final next = m.clues
        .where((i) => !(_found[m.id]?.contains(i) ?? false))
        .firstOrNull;
    if (next == null) return;
    tapFeedback();
    setState(() {
      _hints++;
      (_found[m.id] ??= {}).add(next);
      _miss = false;
    });
  }

  void _decide(_Message m, String decision) {
    decision == 'proceed' ? warnFeedback() : successFeedback();
    setState(() {
      _decisions[m.id] = decision;
      _miss = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final open = _messages.where((m) => m.id == _open).firstOrNull;
    final allDone = _decisions.length == _messages.length;
    return BeatLayout(
      guide: guide(
        open == null
            ? (allDone ? 'c4_inbox_done' : 'c4_inbox_intro')
            : 'c4_msg_intro',
        who: open == null ? 'gullu' : 'asha',
        mood: open == null ? Mood.neutral : Mood.thinking,
      ),
      panel: open == null ? _inbox(context) : _message(context, open),
      bottom: open != null
          ? GameButton(
              key: const ValueKey('inbox_back'),
              label: t('c4_back_inbox'),
              icon: Icons.inbox_rounded,
              style: GameButtonStyle.plain,
              onPressed: () => setState(() {
                _open = null;
                _miss = false;
              }),
            )
          : doneButton(
              'continue',
              result: allDone
                  ? () => {..._decisions, 'clues': _cluesFound, 'hints': _hints}
                  : null,
            ),
    );
  }

  Widget _inbox(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const PropIcon(PropKind.phone, size: 30),
            const SizedBox(width: 6),
            Expanded(
              child: Text(t('c4_inbox'), style: toonTitle(context, size: 18)),
            ),
            TagLabel(t('pretend_message')),
          ],
        ),
        const SizedBox(height: Gap.sm),
        for (final m in _messages)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GameCard(
              key: ValueKey('msg_${m.id}'),
              onTap: () => setState(() => _open = m.id),
              child: Row(
                children: [
                  Icon(
                    switch (_decisions[m.id]) {
                      null => Icons.mark_email_unread_rounded,
                      'proceed' => Icons.warning_amber_rounded,
                      _ => Icons.verified_user_rounded,
                    },
                    color: switch (_decisions[m.id]) {
                      null => Toon.clay,
                      'proceed' => Toon.berry,
                      _ => Toon.leafDark,
                    },
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('c4_${m.id}_from'),
                          style: toonTitle(context, size: 15),
                        ),
                        Text(
                          t('c4_${m.id}_s0'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  TagLabel(
                    t(switch (_decisions[m.id]) {
                      null => 'c4_tag_new',
                      'proceed' => 'c4_tag_risky',
                      _ => 'c4_tag_safe',
                    }),
                    color: switch (_decisions[m.id]) {
                      null => Toon.gold,
                      'proceed' => const Color(0xFFFFD9D9),
                      _ => const Color(0xFFDDF3D6),
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _message(BuildContext context, _Message m) {
    final found = _found[m.id] ?? const <int>{};
    final decision = _decisions[m.id];
    final decided = decision != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
          decoration: toonPanel(color: const Color(0xFF2E2E3A), radius: 24),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sms_outlined, size: 18, color: Toon.ink),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t('c4_${m.id}_from'),
                        style: toonTitle(context, size: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < 4; i++)
                  _Segment(
                    key: ValueKey('seg_${m.id}_$i'),
                    text: t('c4_${m.id}_s$i'),
                    flagged:
                        found.contains(i) || (decided && m.clues.contains(i)),
                    clue: found.contains(i) || (decided && m.clues.contains(i))
                        ? t('c4_${m.id}_k$i')
                        : null,
                    onTap: () => _tapSegment(m, i),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            const PropIcon(PropKind.magnifier, size: 28),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tx('c4_clues_found', {
                  'n': found.length,
                  'total': m.clues.length,
                }),
                key: const ValueKey('clue_count'),
                style: toonTitle(context, size: 15),
              ),
            ),
            if (!decided && found.length < m.clues.length)
              TextButton(
                key: const ValueKey('clue_hint'),
                onPressed: () => _hint(m),
                child: Text(t('show_hint')),
              ),
          ],
        ),
        if (_miss && !decided) Text(t('c4_no_clue')),
        const SizedBox(height: Gap.sm),
        if (!decided) ...[
          Text(t('c4_what_now'), style: toonTitle(context, size: 16)),
          const SizedBox(height: 6),
          for (final (id, icon) in const [
            ('verify', Icons.call_rounded),
            ('report', Icons.report_rounded),
            ('ignore', Icons.delete_outline_rounded),
            ('proceed', Icons.send_rounded),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GameCard(
                key: ValueKey('dec_$id'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                onTap: () => _decide(m, id),
                child: Row(
                  children: [
                    Icon(icon, color: Toon.ink),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t(id == 'proceed' ? 'c4_${m.id}_do' : 'c4_do_$id'),
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ] else
          ToneBanner(
            key: const ValueKey('msg_result'),
            tone: switch (decision) {
              'proceed' => Tone.risky,
              'ignore' => Tone.okay,
              _ => Tone.best,
            },
            title: t(switch (decision) {
              'proceed' => 'c4_res_unsafe',
              'ignore' => 'c4_res_ok',
              _ => 'c4_res_safe',
            }),
            text: tx(
              'c4_${m.id}_${decision == 'proceed'
                  ? 'proceed'
                  : decision == 'ignore'
                  ? 'ignore'
                  : 'safe'}',
              {'loss': min(StoryRules.scamAmounts[m.id]!, widget.s.bank)},
            ),
          ),
      ],
    );
  }
}

/// One tappable part of a message. Flagged parts show why they are odd.
class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.text,
    required this.flagged,
    required this.onTap,
    this.clue,
  });

  final String text;
  final bool flagged;
  final String? clue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: flagged,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: flagged ? const Color(0xFFFFE8A3) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: flagged ? Toon.berry : Colors.black12,
              width: flagged ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(color: Toon.ink, height: 1.25)),
              if (clue != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        size: 16,
                        color: Toon.berry,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          clue!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Toon.berry,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chapter 4, after an unsafe choice: pick the actions that limit the loss.
class RecoverActivity extends ActivityWidget {
  const RecoverActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
  });

  @override
  ConsumerState<RecoverActivity> createState() => _RecoverActivityState();
}

class _RecoverActivityState extends ConsumerState<RecoverActivity>
    with ActivityHelpers {
  static const _actions = ['wait', 'tell', 'reply', 'bank', 'report'];
  static const _right = {'tell', 'bank', 'report'};

  final _picked = <String>{};
  bool _wrong = false;
  bool _resolved = false;

  void _check() {
    if (_picked.length == _right.length && _picked.containsAll(_right)) {
      successFeedback();
      setState(() {
        _resolved = true;
        _wrong = false;
      });
    } else {
      warnFeedback();
      setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final back = max(
      0,
      s.n('c4_lost') - StoryRules.scamUnrecovered * s.n('c4_unsafe'),
    );
    return BeatLayout(
      guide: guide(
        _resolved ? 'c4_recover_after' : 'c4_recover_intro',
        who: 'amma',
        mood: _resolved ? Mood.happy : Mood.worried,
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_resolved) ...[
            Text(t('c4_recover_pick'), style: toonTitle(context, size: 16)),
            const SizedBox(height: Gap.sm),
            for (final action in _actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ChoiceTile(
                  key: ValueKey('rec_$action'),
                  label: t('c4_rec_$action'),
                  selected: _picked.contains(action),
                  onTap: () {
                    tapFeedback();
                    setState(() {
                      if (!_picked.remove(action)) _picked.add(action);
                      _wrong = false;
                    });
                  },
                ),
              ),
            if (_wrong)
              ToneBanner(
                key: const ValueKey('recover_wrong'),
                tone: Tone.risky,
                title: t('st_think_again'),
                text: t('c4_recover_wrong'),
              ),
          ] else ...[
            ToneBanner(
              key: const ValueKey('recover_result'),
              tone: Tone.okay,
              title: t('c4_recover_title'),
              text: tx('c4_recover_done', {
                'back': back,
                'gone': s.n('c4_lost') - back,
              }),
            ),
          ],
        ],
      ),
      bottom: _resolved
          ? doneButton('continue', result: () => const {})
          : GameButton(
              key: const ValueKey('recover_check'),
              label: t('c4_recover_check'),
              onPressed: _picked.isEmpty ? null : _check,
            ),
    );
  }
}
