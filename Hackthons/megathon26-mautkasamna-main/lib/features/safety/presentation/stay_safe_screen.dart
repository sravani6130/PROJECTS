import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/game/characters.dart';
import '../../../core/game/game_widgets.dart';
import '../../../core/game/scenes.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/gullak_scaffold.dart';
import '../../story/application/story_controller.dart';
import '../../story/presentation/chapter_screen.dart';

/// PIN/OTP and scam-safety guidance, reachable from the home screen at any
/// time regardless of progress.
class StaySafeScreen extends ConsumerWidget {
  const StaySafeScreen({super.key});

  /// The chapter about suspicious messages.
  static const safetyChapter = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final language = ref.watch(languageProvider);
    final content = ref.watch(contentProvider);
    final theme = Theme.of(context);
    final reached =
        (ref.watch(storySaveProvider).value?.state.chapter ?? 1) >=
        safetyChapter;

    return GullakScaffold(
      title: t('stay_safe_title'),
      scene: SceneKind.night,
      header: MascotHeader(
        text: t('stay_safe_teaser'),
        mascot: const GullakMascot(mood: Mood.surprised, talking: true),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('stay_safe_intro'), style: theme.textTheme.bodyLarge),
          const SizedBox(height: Gap.md),
          for (final tip in content.safetyTips)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: SectionCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(contentIcon(tip.icon), color: GullakColors.teal),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip.title.of(language),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: Gap.xs),
                          Text(tip.body.of(language)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottom: reached
          ? GameButton(
              icon: Icons.shield_rounded,
              style: GameButtonStyle.secondary,
              label: t('practise_pin_safety'),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const ChapterScreen(number: safetyChapter),
                ),
              ),
            )
          : null,
    );
  }
}
