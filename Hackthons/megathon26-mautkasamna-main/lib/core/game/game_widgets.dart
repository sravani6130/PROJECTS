import 'package:flutter/material.dart';

import '../audio/speak_button.dart';
import '../utils/money_format.dart';
import 'game_style.dart';
import 'props.dart';

enum TailSide { left, right, bottom, none }

/// Cartoon speech bubble. Text types itself in (tap to finish); screen
/// readers always get the full text, and reduced motion shows it at once.
/// When reading aloud is on, the text is spoken as it appears and a speaker
/// button replays it.
class SpeechBubble extends StatefulWidget {
  const SpeechBubble({
    super.key,
    required this.text,
    this.speaker,
    this.tail = TailSide.left,
    this.color = Colors.white,
    this.textKey,
    this.maxHeight,
    this.spokenText,
    this.readAloud = true,
  });

  final String text;

  /// What is read aloud, when it should say more than the bubble shows (for
  /// example the lesson points under a guide's line). Defaults to [text].
  final String? spokenText;

  /// False for bubbles shown before a profile exists or that repeat text
  /// already read elsewhere.
  final bool readAloud;
  final String? speaker;
  final TailSide tail;
  final Color color;
  final Key? textKey;
  final double? maxHeight;

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _typing = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  @override
  void didUpdateWidget(SpeechBubble old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _start();
  }

  void _start() {
    if (!motionEnabled(context)) {
      _typing.value = 1;
      return;
    }
    _typing.duration = Duration(
      milliseconds: (widget.text.characters.length * 22).clamp(300, 2600),
    );
    _typing.forward(from: 0);
  }

  @override
  void dispose() {
    _typing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(fontSize: 17, height: 1.35, color: Toon.ink);
    final chars = widget.text.characters;
    final body = Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _typing.value = 1,
        child: AnimatedBuilder(
          animation: _typing,
          builder: (context, _) {
            final shown = (chars.length * _typing.value).ceil();
            final done = shown >= chars.length;
            return Text.rich(
              key: done ? widget.textKey : null,
              TextSpan(
                children: [
                  TextSpan(text: chars.take(shown).toString()),
                  // Reserve the final layout so the bubble doesn't grow.
                  if (!done)
                    TextSpan(
                      text: chars.skip(shown).toString(),
                      style: const TextStyle(color: Colors.transparent),
                    ),
                ],
              ),
              style: style,
            );
          },
        ),
      ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.speaker != null)
          Text(
            widget.speaker!,
            style: toonTitle(context, size: 15, color: Toon.clayDark),
          ),
        body,
      ],
    );

    final text = widget.maxHeight == null
        ? content
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight!),
            child: SingleChildScrollView(child: content),
          );

    return CustomPaint(
      painter: _BubblePainter(widget.tail, widget.color),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.tail == TailSide.left ? 26 : 16,
          12,
          widget.tail == TailSide.right ? 26 : 16,
          widget.tail == TailSide.bottom ? 26 : 14,
        ),
        child: !widget.readAloud
            ? text
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(child: text),
                  SpeakButton(
                    text: widget.spokenText ?? widget.text,
                    autoPlay: true,
                    size: 32,
                  ),
                ],
              ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.tail, this.color);

  final TailSide tail;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = switch (tail) {
      TailSide.left => const EdgeInsets.only(left: 10),
      TailSide.right => const EdgeInsets.only(right: 10),
      TailSide.bottom => const EdgeInsets.only(bottom: 12),
      TailSide.none => EdgeInsets.zero,
    };
    final r = inset.deflateRect(Offset.zero & size);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(20)));
    final tailPath = switch (tail) {
      TailSide.left =>
        Path()
          ..moveTo(r.left + 1, r.top + 22)
          ..lineTo(0, r.top + 34)
          ..lineTo(r.left + 1, r.top + 40),
      TailSide.right =>
        Path()
          ..moveTo(r.right - 1, r.top + 22)
          ..lineTo(size.width, r.top + 34)
          ..lineTo(r.right - 1, r.top + 40),
      TailSide.bottom =>
        Path()
          ..moveTo(r.left + 30, r.bottom - 1)
          ..lineTo(r.left + 24, size.height)
          ..lineTo(r.left + 48, r.bottom - 1),
      TailSide.none => null,
    };
    final shape = tailPath == null
        ? path
        : Path.combine(PathOperation.union, path, tailPath..close());
    canvas.drawPath(
      shape.shift(const Offset(0, 3)),
      Paint()..color = Toon.ink.withValues(alpha: 0.8),
    );
    canvas.drawPath(shape, Paint()..color = color);
    canvas.drawPath(
      shape,
      Paint()
        ..color = Toon.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = Toon.outline
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.tail != tail || old.color != color;
}

enum GameButtonStyle { primary, secondary, plain, danger }

/// Chunky 3D game button with a press-down animation. Always at least 56 dp
/// tall; disabled buttons turn grey.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = GameButtonStyle.primary,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GameButtonStyle style;
  final bool busy;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final (face, lip, ink) = !enabled
        ? (
            const Color(0xFFD7D2CC),
            const Color(0xFFA9A39C),
            const Color(0xFF7D766F),
          )
        : switch (widget.style) {
            GameButtonStyle.primary => (Toon.clay, Toon.clayDark, Colors.white),
            GameButtonStyle.secondary => (
              Toon.teal,
              Toon.tealDark,
              Colors.white,
            ),
            GameButtonStyle.plain => (
              Colors.white,
              const Color(0xFFBFAF9F),
              Toon.ink,
            ),
            GameButtonStyle.danger => (
              Toon.berry,
              darken(Toon.berry),
              Colors.white,
            ),
          };
    const lipHeight = 5.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: enabled ? widget.onPressed : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56 + lipHeight),
          child: Stack(
            children: [
              Positioned.fill(
                top: lipHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: lip,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Toon.ink, width: Toon.outline),
                  ),
                ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 70),
                padding: EdgeInsets.only(
                  top: _down ? lipHeight : 0,
                  bottom: _down ? 0 : lipHeight,
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: face,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Toon.ink, width: Toon.outline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.busy)
                        SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: ink,
                          ),
                        )
                      else ...[
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: ink, size: 24),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            style: toonTitle(context, size: 18, color: ink),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coin or rupee counter that bumps when its value changes.
class CoinCounter extends StatefulWidget {
  const CoinCounter({
    super.key,
    required this.amount,
    required this.coins,
    required this.coinsLabel,
    this.label,
  });

  final int amount;
  final bool coins;
  final String coinsLabel;
  final String? label;

  @override
  State<CoinCounter> createState() => _CoinCounterState();
}

class _CoinCounterState extends State<CoinCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void didUpdateWidget(CoinCounter old) {
    super.didUpdateWidget(old);
    if (old.amount != widget.amount && motionEnabled(context)) {
      _bump.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  String _format(int v) => widget.coins
      ? '${formatAmount(v)} ${widget.coinsLabel}'
      : formatRupees(v);

  @override
  Widget build(BuildContext context) {
    final finalText = _format(widget.amount);
    return Semantics(
      label: widget.label == null ? finalText : '${widget.label}: $finalText',
      excludeSemantics: true,
      child: ScaleTransition(
        scale: TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 1),
        ]).animate(_bump),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
          decoration: toonPanel(color: Toon.cream, radius: 30, shadow: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 30),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.label != null)
                      Text(
                        widget.label!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Toon.clayDark,
                          height: 1.1,
                        ),
                      ),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(end: widget.amount),
                      duration: motionEnabled(context)
                          ? const Duration(milliseconds: 700)
                          : Duration.zero,
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) =>
                          Text(_format(v), style: toonTitle(context, size: 20)),
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

/// Round cartoon icon button (used in the HUD). Wraps a real [BackButton]
/// when [back] is true so system semantics and tooling still recognise it.
class RoundGameButton extends StatelessWidget {
  const RoundGameButton({
    super.key,
    this.icon,
    this.onPressed,
    this.tooltip,
    this.back = false,
  });

  final IconData? icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool back;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: toonPanel(color: Colors.white, radius: 24, shadow: 3),
      child: back
          ? BackButton(color: Toon.ink, onPressed: onPressed)
          : IconButton(
              tooltip: tooltip,
              icon: Icon(icon, color: Toon.ink),
              onPressed: onPressed,
            ),
    );
  }
}

/// Pops [child] in with a springy scale when first shown.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (!motionEnabled(context)) return child;
    final total = delay + const Duration(milliseconds: 450);
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, t, child) {
        final local = start >= 1
            ? 1.0
            : ((t - start) / (1 - start)).clamp(0.0, 1.0);
        final scale = Curves.elasticOut.transform(local);
        return Opacity(
          opacity: local.clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}

/// Gullu the mascot with a speech bubble, used as a guide above panels.
class MascotHeader extends StatelessWidget {
  const MascotHeader({
    super.key,
    required this.text,
    required this.mascot,
    this.height = 130,
    this.speaker,
  });

  final String text;
  final String? speaker;

  /// Usually a `GullakMascot`; passed in to keep this file free of painters.
  final Widget mascot;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(width: height * 0.75, child: mascot),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: SpeechBubble(
                  text: text,
                  speaker: speaker,
                  maxHeight: height - 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
