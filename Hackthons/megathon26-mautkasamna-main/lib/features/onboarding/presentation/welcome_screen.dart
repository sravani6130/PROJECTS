import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/game/characters.dart';
import '../../../core/game/game_style.dart';
import '../../../core/game/game_widgets.dart';
import '../../../core/game/scenes.dart';
import '../../../core/localization/app_language.dart';
import '../../profiles/application/app_session_controller.dart';

/// Title screen: Gullu the gullak greets the player over the Hyderabad
/// skyline and asks for a language.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key, required this.onLanguageChosen});

  final VoidCallback onLanguageChosen;

  Future<void> _choose(WidgetRef ref, AppLanguage language) async {
    await ref.read(appSessionProvider.notifier).selectLanguage(language);
    onLanguageChosen();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Scaffold(
      body: SceneBackground(
        scene: SceneKind.city,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PopIn(
                  child: Text(
                    t('app_name'),
                    textAlign: TextAlign.center,
                    style: toonTitle(context, size: 52, color: Colors.white)
                        .copyWith(
                          shadows: const [
                            Shadow(color: Toon.ink, offset: Offset(0, 4)),
                            Shadow(color: Toon.ink, offset: Offset(2, 0)),
                            Shadow(color: Toon.ink, offset: Offset(-2, 0)),
                            Shadow(color: Toon.ink, offset: Offset(0, -2)),
                          ],
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: toonPanel(color: Toon.cream, radius: 16),
                  child: Text(
                    t('tagline'),
                    textAlign: TextAlign.center,
                    style: toonTitle(context, size: 16),
                  ),
                ),
                const SizedBox(height: Gap.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(
                      width: 120,
                      child: GullakMascot(mood: Mood.cheer, talking: true),
                    ),
                    Expanded(child: SpeechBubble(text: t('welcome_body'))),
                  ],
                ),
                const SizedBox(height: Gap.md),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: toonPanel(color: Toon.gold, radius: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.info_rounded, color: Toon.ink),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          t('pretend_money_short'),
                          style: toonTitle(context, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.lg),
                Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: toonPanel(color: Toon.cream),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t('choose_language'),
                        textAlign: TextAlign.center,
                        style: toonTitle(context, size: 18),
                      ),
                      const SizedBox(height: Gap.md),
                      // Language names are always shown in their own script.
                      GameButton(
                        key: const ValueKey('lang_en'),
                        label: 'English',
                        onPressed: () => _choose(ref, AppLanguage.en),
                      ),
                      const SizedBox(height: Gap.sm),
                      GameButton(
                        key: const ValueKey('lang_te'),
                        label: 'తెలుగు',
                        style: GameButtonStyle.secondary,
                        onPressed: () => _choose(ref, AppLanguage.te),
                      ),
                    ],
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
