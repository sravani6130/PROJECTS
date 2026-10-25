import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/audio/speak_button.dart';
import '../../../core/game/characters.dart';
import '../../../core/game/game_style.dart';
import '../../../core/game/game_widgets.dart';
import '../../../core/game/props.dart';
import '../../../core/utils/money_format.dart';

/// The recurring characters of The Money Diaries. A null look is Gullu, the
/// clay-pot mascot.
const storyCast = <String, CharacterLook?>{
  'asha': CharacterLook(
    hair: HairStyle.braid,
    top: Color(0xFFE5577A),
    accessory: Accessory.bindi,
  ),
  'amma': CharacterLook(
    skin: Color(0xFFBF8156),
    hair: HairStyle.bun,
    top: Color(0xFF3F9E6E),
    bottom: Color(0xFF2D6E4E),
    accessory: Accessory.bindi,
  ),
  'nanna': CharacterLook(
    skin: Color(0xFFA9714A),
    top: Color(0xFF4E6FA8),
    accessory: Accessory.glasses,
  ),
  'ravi': CharacterLook(
    skin: Color(0xFF9C6644),
    hair: HairStyle.curly,
    top: Color(0xFFF0A23A),
  ),
  'farida': CharacterLook(
    skin: Color(0xFFD9A066),
    hair: HairStyle.long,
    top: Color(0xFF8E6CD8),
    accessory: Accessory.glasses,
  ),
  'imran': CharacterLook(
    skin: Color(0xFFB97F55),
    top: Color(0xFF2E9CB8),
    accessory: Accessory.cap,
  ),
  'lakshmi': CharacterLook(
    skin: Color(0xFF8D5A3B),
    hair: HairStyle.ponytail,
    top: Color(0xFFD9475B),
    bottom: Color(0xFF5A2A3A),
  ),
  'gullu': null,
};

Mood moodOf(String name) =>
    Mood.values.where((m) => m.name == name).firstOrNull ?? Mood.neutral;

void tapFeedback() => HapticFeedback.selectionClick();
void successFeedback() => HapticFeedback.mediumImpact();
void warnFeedback() => HapticFeedback.heavyImpact();

/// Full-body cast member (or the mascot).
class CastFigure extends StatelessWidget {
  const CastFigure({
    super.key,
    required this.who,
    this.mood = Mood.neutral,
    this.talking = false,
    this.label,
  });

  final String who;
  final Mood mood;
  final bool talking;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final look = storyCast[who];
    return look == null
        ? GullakMascot(mood: mood, talking: talking, semanticLabel: label)
        : CartoonCharacter(
            look: look,
            mood: mood,
            talking: talking,
            semanticLabel: label,
          );
  }
}

/// Standard layout for a beat: a guide on the scene, the game panel and one
/// pinned action area.
class BeatLayout extends StatelessWidget {
  const BeatLayout({
    super.key,
    this.guide,
    required this.panel,
    required this.bottom,
  });

  final Widget? guide;
  final Widget panel;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ?guide,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
            child: DecoratedBox(
              decoration: toonPanel(color: Toon.cream),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: panel,
                ),
              ),
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.all(Gap.md), child: bottom),
      ],
    );
  }
}

/// A small character with a speech bubble: the instruction for an activity.
class GuideStrip extends StatelessWidget {
  const GuideStrip({
    super.key,
    required this.who,
    required this.text,
    this.speaker,
    this.mood = Mood.neutral,
    this.spokenText,
  });

  final String who;
  final String text;

  /// Read aloud instead of [text] when the guide introduces more on screen.
  final String? spokenText;
  final String? speaker;
  final Mood mood;

  /// Shorter on small phones so the game panel keeps most of the screen.
  static double heightFor(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 700 ? 96 : 132;

  @override
  Widget build(BuildContext context) {
    final height = heightFor(context);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.md, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 78,
              child: CastFigure(who: who, mood: mood, label: speaker),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SpeechBubble(
                  text: text,
                  spokenText: spokenText,
                  speaker: speaker,
                  maxHeight: height - 42,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact HUD counter for one pot of money. Bumps when the value changes.
class MoneyChip extends StatelessWidget {
  const MoneyChip({
    super.key,
    required this.label,
    required this.amount,
    required this.prop,
    this.color = Toon.cream,
  });

  final String label;
  final int amount;
  final PropKind prop;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${formatRupees(amount)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 10, 3),
        decoration: toonPanel(color: color, radius: 16, shadow: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PropIcon(prop, size: 24),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: Toon.clayDark,
                  ),
                ),
                TweenAnimationBuilder<int>(
                  tween: IntTween(end: amount),
                  duration: motionEnabled(context)
                      ? const Duration(milliseconds: 600)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    formatRupees(v),
                    style: toonTitle(context, size: 15),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined progress bar. [over] turns it red; text beside it must state
/// the same information.
class Meter extends StatelessWidget {
  const Meter({
    super.key,
    required this.value,
    this.color = Toon.leaf,
    this.height = 20,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: toonPanel(color: Colors.white, radius: 12, shadow: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: motionEnabled(context)
              ? const Duration(milliseconds: 400)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          builder: (context, f, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: f.clamp(0.0, 1.0),
            child: ColoredBox(color: color),
          ),
        ),
      ),
    );
  }
}

/// Asha's savings jar: fills with coins as [fill] grows from 0 to 1.
class JarView extends StatelessWidget {
  const JarView({super.key, required this.fill, this.size = 110});

  final double fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fill.clamp(0.0, 1.0)),
        duration: motionEnabled(context)
            ? const Duration(milliseconds: 700)
            : Duration.zero,
        curve: Curves.easeOutBack,
        builder: (context, f, _) => SizedBox(
          width: size * 0.8,
          height: size,
          child: CustomPaint(painter: _JarPainter(f.clamp(0.0, 1.0))),
        ),
      ),
    );
  }
}

class _JarPainter extends CustomPainter {
  _JarPainter(this.fill);

  final double fill;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    final ink = Paint()
      ..color = Toon.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = Toon.outline
      ..strokeJoin = StrokeJoin.round;
    final body = Path()
      ..moveTo(w * 0.28, h * 0.16)
      ..quadraticBezierTo(w * 0.02, h * 0.3, w * 0.06, h * 0.7)
      ..quadraticBezierTo(w * 0.1, h * 0.97, w * 0.5, h * 0.97)
      ..quadraticBezierTo(w * 0.9, h * 0.97, w * 0.94, h * 0.7)
      ..quadraticBezierTo(w * 0.98, h * 0.3, w * 0.72, h * 0.16)
      ..close();
    c.drawPath(body.shift(const Offset(0, 3)), Paint()..color = Toon.ink);
    c.drawPath(body, Paint()..color = const Color(0xFFE6F6FF));
    c.save();
    c.clipPath(body);
    final top = h * (0.97 - 0.78 * fill);
    c.drawRect(Rect.fromLTRB(0, top, w, h), Paint()..color = Toon.gold);
    if (fill > 0) {
      // A row of coin tops along the surface.
      for (var x = w * 0.08; x < w; x += w * 0.2) {
        final r = Rect.fromCenter(
          center: Offset(x + w * 0.04, top),
          width: w * 0.22,
          height: h * 0.07,
        );
        c.drawOval(r, Paint()..color = const Color(0xFFFFD66B));
        c.drawOval(
          r,
          Paint()
            ..color = Toon.goldDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    // Glass shine.
    c.drawLine(
      Offset(w * 0.2, h * 0.4),
      Offset(w * 0.17, h * 0.66),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    c.restore();
    c.drawPath(body, ink);
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.04, w * 0.56, h * 0.14),
      const Radius.circular(6),
    );
    c.drawRRect(lid, Paint()..color = Toon.clay);
    c.drawRRect(lid, ink);
    c.drawLine(
      Offset(w * 0.4, h * 0.11),
      Offset(w * 0.6, h * 0.11),
      Paint()
        ..color = Toon.ink
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_JarPainter old) => old.fill != fill;
}

/// − / + stepper with a slider, for choosing a rupee amount.
class AmountStepper extends StatelessWidget {
  const AmountStepper({
    super.key,
    required this.value,
    required this.max,
    required this.step,
    required this.onChanged,
    this.label,
  });

  final int value;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;
  final String? label;

  void _set(int v) {
    final next = v.clamp(0, max);
    if (next != value) {
      tapFeedback();
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, int delta, String key) => Container(
      width: 48,
      height: 48,
      decoration: toonPanel(color: Colors.white, radius: 24, shadow: 3),
      child: IconButton(
        key: ValueKey(key),
        icon: Icon(icon, color: Toon.ink),
        onPressed: () => _set(value + delta),
      ),
    );
    return Semantics(
      label: label,
      value: formatRupees(value),
      child: Row(
        children: [
          button(Icons.remove_rounded, -step, 'amount_minus'),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatRupees(value),
                  key: const ValueKey('amount_value'),
                  style: toonTitle(context, size: 24),
                ),
                if (max > 0)
                  Slider(
                    value: value.toDouble().clamp(0, max.toDouble()),
                    max: max.toDouble(),
                    divisions: max ~/ step > 0 ? (max / step).ceil() : null,
                    activeColor: Toon.clay,
                    onChanged: (v) => _set(min(max, (v / step).round() * step)),
                  ),
              ],
            ),
          ),
          button(Icons.add_rounded, step, 'amount_plus'),
        ],
      ),
    );
  }
}

enum Tone { best, okay, risky }

Tone toneOf(String name) =>
    Tone.values.where((t) => t.name == name).firstOrNull ?? Tone.okay;

/// Feedback card: colour, icon and words together say how it went. It is
/// read aloud when it appears, since it answers what the player just did.
class ToneBanner extends StatelessWidget {
  const ToneBanner({
    super.key,
    required this.tone,
    required this.title,
    required this.text,
  });

  final Tone tone;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tone) {
      Tone.best => (Toon.leafDark, Icons.check_circle_rounded),
      Tone.okay => (Toon.tealDark, Icons.info_rounded),
      Tone.risky => (Toon.berry, Icons.warning_amber_rounded),
    };
    return PopIn(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: toonPanel(color: Colors.white, radius: 18, shadow: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: toonTitle(context, size: 17, color: color),
                  ),
                ),
                SpeakButton(text: '$title. $text', autoPlay: true, size: 32),
              ],
            ),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontSize: 15, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

/// A labelled row: `label ........ ₹amount`.
class FactRow extends StatelessWidget {
  const FactRow({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
    this.color,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                height: 1.25,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Text(
            value,
            style: toonTitle(context, size: strong ? 18 : 16, color: color),
          ),
        ],
      ),
    );
  }
}

/// Small rounded tag (for example "Pretend bank").
class TagLabel extends StatelessWidget {
  const TagLabel(this.text, {super.key, this.color = Toon.gold});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Toon.ink, width: 1.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: Toon.ink,
        ),
      ),
    );
  }
}

/// White outlined card used inside activity panels.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: padding,
      decoration: toonPanel(
        color: selected ? const Color(0xFFFFE8A3) : color,
        radius: 18,
        shadow: selected ? 5 : 3,
      ),
      child: child,
    );
    return onTap == null
        ? card
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              tapFeedback();
              onTap!();
            },
            child: card,
          );
  }
}
