import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/game/game_style.dart';
import '../../../core/game/scenes.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/gullak_scaffold.dart';

/// Opens the level screen again after onboarding (from the map or
/// Settings). Easy is the level being played, so choosing it goes back.
void openLevelSelect(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => LevelSelectScreen(
      onEasy: () => Navigator.of(context).pop(),
      onBack: () => Navigator.of(context).pop(),
    ),
  ),
);

/// Level choice as islands. Only Easy is built; Medium and Advanced are
/// greyed-out, non-interactive "coming later" islands.
class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({
    super.key,
    required this.onEasy,
    required this.onBack,
  });

  final VoidCallback onEasy;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return GullakScaffold(
      onBack: onBack,
      title: t('level_title'),
      scene: SceneKind.park,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('level_body'), style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: Gap.md),
          _Island(
            key: const ValueKey('level_easy'),
            scene: SceneKind.college,
            title: t('level_easy'),
            description: t('level_easy_desc'),
            onTap: onEasy,
          ),
          const SizedBox(height: Gap.md),
          _Island(
            scene: SceneKind.city,
            title: t('level_medium'),
            description: t('level_medium_desc'),
            comingLater: t('coming_later'),
          ),
          const SizedBox(height: Gap.md),
          _Island(
            scene: SceneKind.sunrise,
            title: t('level_advanced'),
            description: t('level_advanced_desc'),
            comingLater: t('coming_later'),
          ),
        ],
      ),
    );
  }
}

class _Island extends StatelessWidget {
  const _Island({
    super.key,
    required this.scene,
    required this.title,
    required this.description,
    this.onTap,
    this.comingLater,
  });

  final SceneKind scene;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final String? comingLater;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: enabled,
      enabled: enabled,
      label: [title, description, ?comingLater].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: toonPanel(radius: 22, shadow: enabled ? 6 : 3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColorFiltered(
                    colorFilter: enabled
                        ? const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.dst,
                          )
                        : const ColorFilter.matrix([
                            0.33, 0.33, 0.33, 0, 20, //
                            0.33, 0.33, 0.33, 0, 20, //
                            0.33, 0.33, 0.33, 0, 20, //
                            0, 0, 0, 1, 0,
                          ]),
                    child: SceneBackground(scene: scene),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 72, 10, 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: toonPanel(
                      color: Toon.cream,
                      radius: 14,
                      shadow: 2,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          enabled
                              ? Icons.play_circle_fill_rounded
                              : Icons.lock_rounded,
                          size: 36,
                          color: enabled
                              ? Toon.clay
                              : Toon.ink.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: toonTitle(context, size: 20)),
                              Text(
                                description,
                                style: const TextStyle(height: 1.15),
                              ),
                              if (comingLater != null)
                                StatusPill(
                                  icon: Icons.schedule,
                                  label: comingLater!,
                                  color: Toon.ink,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
