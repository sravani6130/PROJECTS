import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../utils/money_format.dart';

/// A labelled card section with consistent padding.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.color, this.onTap});

  final Widget child;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(Gap.md), child: child),
      ),
    );
  }
}

/// Fictional balance with a short counting animation when it changes.
class BalanceDisplay extends StatelessWidget {
  const BalanceDisplay({
    super.key,
    required this.label,
    required this.amount,
    required this.coins,
    required this.coinsLabel,
  });

  final String label;
  final int amount;
  final bool coins;
  final String coinsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: ${coins ? '$amount $coinsLabel' : formatRupees(amount)}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.savings_outlined, color: scheme.onSecondaryContainer),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(end: amount),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      coins
                          ? '${formatAmount(value)} $coinsLabel'
                          : formatRupees(value),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Short status label with an icon, so meaning never relies on colour alone.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Gap.xs),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner for investing screens: everything is simulated.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onTertiaryContainer, size: 20),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three stars; filled count is [stars].
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 28});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            color: const Color(0xFFE0A100),
            size: size,
          ),
      ],
    );
  }
}

/// Friendly full-page message for empty and error states.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: Gap.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (action != null) ...[const SizedBox(height: Gap.lg), action!],
          ],
        ),
      ),
    );
  }
}
