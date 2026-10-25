import '../audio/speak_button.dart';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../utils/money_format.dart';
import 'game_style.dart';
import 'props.dart';

/// Budget capacity bar: fills as items are added and turns red past the
/// limit. Text states the numbers too, so colour is never the only signal.
class WalletMeter extends ConsumerWidget {
  const WalletMeter({super.key, required this.total, required this.budget});

  final int total;
  final int budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final over = total > budget;
    final fill = budget == 0 ? (total > 0 ? 1.0 : 0.0) : (total / budget);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const CoinIcon(size: 26),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                t('planned_total', {'total': total, 'budget': budget}),
                key: const ValueKey('budget_total'),
                style: toonTitle(context, size: 17),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 22,
          decoration: toonPanel(color: Colors.white, radius: 12, shadow: 2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fill.clamp(0.0, 1.0)),
              duration: motionEnabled(context)
                  ? const Duration(milliseconds: 350)
                  : Duration.zero,
              curve: Curves.easeOutBack,
              builder: (context, f, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: f.clamp(0.0, 1.0),
                child: Container(color: over ? Toon.berry : Toon.leaf),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              over ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              size: 18,
              color: over ? Toon.berry : Toon.leafDark,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                over
                    ? t('over_by', {'amount': total - budget})
                    : t('left_amount', {'amount': budget - total}),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: over ? Toon.berry : Toon.leafDark,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Selectable item token for budget missions: an illustrated prop, its
/// label and price tag. Selected tokens lift up with a tick.
class ItemToken extends StatelessWidget {
  const ItemToken({
    super.key,
    required this.label,
    required this.cost,
    required this.prop,
    required this.selected,
    required this.onTap,
    this.tag,
  });

  final String label;
  final int cost;
  final PropKind prop;
  final bool selected;
  final VoidCallback onTap;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, ${formatRupees(cost)}${tag == null ? '' : ', $tag'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
          padding: const EdgeInsets.all(8),
          decoration: toonPanel(
            color: selected ? const Color(0xFFFFE8A3) : Colors.white,
            radius: 18,
            shadow: selected ? 5 : 3,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PropIcon(prop, size: 46),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: Toon.ink,
                    ),
                  ),
                  if (tag != null)
                    Text(
                      tag!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Toon.clayDark,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Toon.gold,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Toon.ink, width: 1.5),
                    ),
                    child: Text(
                      formatRupees(cost),
                      style: toonTitle(context, size: 14),
                    ),
                  ),
                ],
              ),
              if (selected)
                const Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Toon.leaf,
                    child: Icon(Icons.check, size: 16, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A big answer card with an illustration, used for single-choice steps.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.prop,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final PropKind? prop;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: toonPanel(
            color: selected ? const Color(0xFFFFE8A3) : Colors.white,
            radius: 18,
            shadow: selected ? 5 : 3,
          ),
          child: Row(
            children: [
              if (prop != null) ...[
                PropIcon(prop!, size: 40),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: Toon.ink,
                  ),
                ),
              ),
              SpeakButton(text: label, size: 32),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  key: ValueKey(selected),
                  color: selected
                      ? Toon.leafDark
                      : Toon.ink.withValues(alpha: 0.4),
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pretend phone showing the scam message. The link is plain text: it is
/// not tappable and opens nothing.
class PhoneMock extends StatefulWidget {
  const PhoneMock({
    super.key,
    required this.sender,
    required this.text,
    required this.badge,
    this.link,
  });

  final String sender;
  final String text;
  final String badge;
  final String? link;

  @override
  State<PhoneMock> createState() => _PhoneMockState();
}

class _PhoneMockState extends State<PhoneMock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _buzz = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionEnabled(context) && _buzz.value == 0) _buzz.forward();
  }

  @override
  void dispose() {
    _buzz.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _buzz,
      builder: (context, child) => Transform.translate(
        offset: Offset(sin(_buzz.value * pi * 10) * 4 * (1 - _buzz.value), 0),
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 18),
        decoration: toonPanel(color: const Color(0xFF2E2E3A), radius: 26),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sms_outlined, size: 18, color: Toon.ink),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.sender,
                      overflow: TextOverflow.ellipsis,
                      style: toonTitle(context, size: 15),
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Toon.gold,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Toon.ink, width: 1.2),
                      ),
                      child: Text(
                        widget.badge,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Toon.ink),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.text, style: const TextStyle(color: Toon.ink)),
                    if (widget.link != null)
                      Text(
                        widget.link!,
                        style: const TextStyle(
                          color: Color(0xFF1A63C9),
                          decoration: TextDecoration.underline,
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
