import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/game/effects.dart';
import '../../../core/game/game_style.dart';
import '../../../core/game/game_widgets.dart';
import '../../../core/game/props.dart';
import '../application/daily_providers.dart';
import '../domain/daily_rules.dart';
import 'inbox_screen.dart';

/// Checks in automatically: when [child] (the home screen) first appears and
/// whenever the app comes back to the front, which may be on a new day.
class DailyAutoCheckIn extends ConsumerStatefulWidget {
  const DailyAutoCheckIn({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DailyAutoCheckIn> createState() => _DailyAutoCheckInState();
}

class _DailyAutoCheckInState extends ConsumerState<DailyAutoCheckIn> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _checkIn);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkIn());
  }

  void _checkIn() {
    if (!mounted) return;
    ref.invalidate(dailyStatusProvider);
    ref.read(dailyActionsProvider).autoCheckIn();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Compact home-screen card: streak, pretend savings, the week's bonus dots
/// and the notifications bell. Today's reward is collected automatically.
class DailyCard extends ConsumerWidget {
  const DailyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final status = ref.watch(dailyStatusProvider).value;
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final today = ref.watch(todayCheckInProvider);
    if (status == null) return const SizedBox(height: Gap.sm);

    final streak = status.streak > 0
        ? t('daily_streak', {'streak': status.streak})
        : t('daily_no_streak');
    final saved = t('daily_saved', {'total': status.total});
    final plus = today == null
        ? null
        : t('daily_today_plus', {'reward': today.total});

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.md),
      child: Container(
        key: const ValueKey('daily_card'),
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
        decoration: toonPanel(color: const Color(0xFFFFF1C9)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 36,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const PropIcon(PropKind.jar, size: 36),
                      // Coins drop into the jar when today's reward lands.
                      if (today != null)
                        const Positioned(
                          left: -10,
                          top: -40,
                          width: 56,
                          height: 76,
                          child: CoinBurst(
                            from: Alignment.topRight,
                            to: Alignment.bottomCenter,
                            count: 5,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Semantics(
                    label: [t('daily_title'), ?plus, streak, saved].join('. '),
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: t('daily_title')),
                              if (plus != null)
                                TextSpan(
                                  text: '  $plus',
                                  style: const TextStyle(color: Toon.leafDark),
                                ),
                            ],
                          ),
                          key: const ValueKey('daily_title'),
                          style: toonTitle(context, size: 16),
                        ),
                        Text(
                          '$streak · $saved',
                          key: const ValueKey('daily_streak'),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Toon.clayDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _InboxBell(
                  unread: unread,
                  label: t('inbox_open'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const InboxScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Semantics(
              label: t('daily_week', {'bonus': DailyRules.weeklyBonus}),
              value: '${status.weekProgress} / ${DailyRules.week}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Expanded(child: _WeekDots(filled: status.weekProgress)),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.card_giftcard_rounded,
                    size: 16,
                    color: Toon.clayDark,
                  ),
                  Text(
                    ' ₹${DailyRules.weeklyBonus}',
                    style: toonTitle(context, size: 13, color: Toon.clayDark),
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

/// Seven small pills for the week; filling all seven pays the bonus.
class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= DailyRules.week; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 12,
                decoration: BoxDecoration(
                  color: i <= filled ? Toon.gold : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Toon.ink, width: 1.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InboxBell extends StatelessWidget {
  const _InboxBell({
    required this.unread,
    required this.label,
    required this.onPressed,
  });

  final int unread;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RoundGameButton(
          key: const ValueKey('open_inbox'),
          tooltip: label,
          icon: unread > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_rounded,
          onPressed: onPressed,
        ),
        if (unread > 0)
          Positioned(
            right: -4,
            top: -4,
            child: IgnorePointer(
              child: Container(
                key: const ValueKey('inbox_badge'),
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Toon.berry,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Toon.ink, width: 1.5),
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
