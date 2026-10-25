import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/game/characters.dart';
import '../../../../core/game/game_style.dart';
import '../../../../core/game/game_widgets.dart';
import '../../../../core/game/props.dart';
import '../story_widgets.dart';
import 'activity_base.dart';

class SortCard {
  const SortCard(this.label, this.prop, {required this.left, this.why});

  final String label;
  final String prop;

  /// True when the card belongs in the left bin.
  final bool left;

  /// Explanation shown once the card is placed.
  final String? why;
}

/// Sort cards into two bins, one at a time. A wrong bin explains itself and
/// the card stays until it is placed correctly.
class SortActivity extends ActivityWidget {
  const SortActivity({
    super.key,
    required super.s,
    required super.onDone,
    super.busy,
    required this.intro,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftIcon,
    required this.rightIcon,
    required this.cards,
  });

  final String intro;
  final String leftLabel;
  final String rightLabel;
  final IconData leftIcon;
  final IconData rightIcon;
  final List<SortCard> cards;

  @override
  ConsumerState<SortActivity> createState() => _SortActivityState();
}

class _SortActivityState extends ConsumerState<SortActivity>
    with ActivityHelpers {
  int _index = 0;
  int _mistakes = 0;
  bool _wrong = false;
  String? _lastWhy;

  bool get _finished => _index >= widget.cards.length;

  void _drop(bool left) {
    if (_finished) return;
    final card = widget.cards[_index];
    if (card.left == left) {
      successFeedback();
      setState(() {
        _lastWhy = card.why;
        _wrong = false;
        _index++;
      });
    } else {
      warnFeedback();
      setState(() {
        _mistakes++;
        _wrong = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _finished ? null : widget.cards[_index];
    Widget bin(bool left) => Expanded(
      child: GameCard(
        key: ValueKey(left ? 'bin_left' : 'bin_right'),
        color: left ? const Color(0xFFDDF3D6) : const Color(0xFFFFE3D2),
        onTap: _finished ? null : () => _drop(left),
        child: Column(
          children: [
            Icon(
              left ? widget.leftIcon : widget.rightIcon,
              size: 30,
              color: Toon.ink,
            ),
            Text(
              t(left ? widget.leftLabel : widget.rightLabel),
              textAlign: TextAlign.center,
              style: toonTitle(context, size: 16),
            ),
          ],
        ),
      ),
    );

    return BeatLayout(
      guide: guide(
        widget.intro,
        who: 'asha',
        mood: _finished ? Mood.cheer : Mood.thinking,
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('page_of', {
              'n': _finished ? widget.cards.length : _index + 1,
              'total': widget.cards.length,
            }),
            textAlign: TextAlign.center,
            style: toonTitle(context, size: 14),
          ),
          const SizedBox(height: Gap.sm),
          if (card != null)
            PopIn(
              key: ValueKey('card_$_index'),
              child: GameCard(
                child: Column(
                  children: [
                    PropIcon(PropKind.parse(card.prop), size: 64),
                    const SizedBox(height: 4),
                    Text(
                      tx(card.label),
                      key: const ValueKey('sort_card'),
                      textAlign: TextAlign.center,
                      style: toonTitle(context, size: 19),
                    ),
                  ],
                ),
              ),
            )
          else
            ToneBanner(
              tone: Tone.best,
              title: t('st_sorted'),
              text: t(_mistakes == 0 ? 'st_sorted_clean' : 'st_sorted_some'),
            ),
          const SizedBox(height: Gap.md),
          if (!_finished)
            Row(children: [bin(true), const SizedBox(width: 12), bin(false)]),
          if (_wrong && card != null) ...[
            const SizedBox(height: Gap.md),
            ToneBanner(
              tone: Tone.risky,
              title: t('st_think_again'),
              text: card.why == null ? t('st_other_bin') : tx(card.why!),
            ),
          ] else if (_lastWhy != null && !_finished) ...[
            const SizedBox(height: Gap.md),
            ToneBanner(
              key: ValueKey('why_$_index'),
              tone: Tone.best,
              title: t('st_correct'),
              text: tx(_lastWhy!),
            ),
          ],
        ],
      ),
      bottom: doneButton(
        'continue',
        result: _finished ? () => {'mistakes': _mistakes} : null,
      ),
    );
  }
}
