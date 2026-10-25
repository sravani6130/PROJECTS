import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/game/characters.dart';
import '../../../core/game/game_style.dart';
import '../../../core/game/game_widgets.dart';
import '../../../core/game/scenes.dart';
import '../../../core/widgets/gullak_scaffold.dart';

/// Gullu explains that every amount, account and asset is fictional.
class NoticeScreen extends ConsumerWidget {
  const NoticeScreen({super.key, required this.onAccept, required this.onBack});

  final VoidCallback onAccept;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    const points = [
      (Icons.toll_rounded, Toon.gold, 'notice_point_fictional'),
      (Icons.money_off_rounded, Toon.berry, 'notice_point_no_payments'),
      (Icons.trending_up_rounded, Toon.teal, 'notice_point_simulation'),
      (Icons.privacy_tip_rounded, Toon.clay, 'notice_point_privacy'),
      (Icons.wifi_off_rounded, Toon.leafDark, 'notice_point_offline'),
    ];
    return GullakScaffold(
      onBack: onBack,
      title: t('notice_title'),
      scene: SceneKind.home,
      header: SizedBox(
        height: 130,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 100, child: GullakMascot(talking: true)),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SpeechBubble(text: t('notice_heading')),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          for (final (i, (icon, color, key)) in points.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: PopIn(
                delay: Duration(milliseconds: 120 * i),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Toon.ink, width: 2),
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        t(key),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottom: GameButton(
        key: const ValueKey('notice_accept'),
        label: t('notice_accept'),
        icon: Icons.thumb_up_alt_rounded,
        onPressed: onAccept,
      ),
    );
  }
}
