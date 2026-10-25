import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/game/characters.dart';
import '../../../core/game/game_style.dart';
import '../../../core/game/game_widgets.dart';
import '../../../core/game/scenes.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/gullak_scaffold.dart';
import '../application/app_session_controller.dart';
import 'profile_form.dart';

/// "Who is playing?" for shared devices. Each profile has its own progress.
class ProfilePickerScreen extends ConsumerWidget {
  const ProfilePickerScreen({super.key, this.atLaunch = false});

  /// At launch the picker is the root screen; otherwise it is a route.
  final bool atLaunch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final session = ref.watch(appSessionProvider).value;
    final profiles = session?.profiles ?? const [];
    final activeId = session?.activeProfile?.id;

    Future<void> pick(int id) async {
      await ref.read(appSessionProvider.notifier).switchProfile(id);
      if (!atLaunch && context.mounted) Navigator.of(context).pop();
    }

    return GullakScaffold(
      title: t('who_is_playing'),
      showBack: !atLaunch,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in profiles)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: SectionCard(
                onTap: () => pick(p.id),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFBFE8FF),
                          border: Border.all(color: Toon.ink, width: 2.5),
                        ),
                        child: ClipOval(
                          child: CartoonFace(
                            look:
                                CharacterLook.avatars[p.avatarId] ??
                                CharacterLook.avatars['star']!,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        profileDisplayName(p, t),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (p.id == activeId)
                      Flexible(
                        child: StatusPill(
                          icon: Icons.check,
                          label: t('profile_current'),
                          color: GullakColors.success,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      scene: SceneKind.home,
      bottom: GameButton(
        icon: Icons.person_add_alt,
        label: t('profile_add'),
        style: GameButtonStyle.secondary,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProfileFormScreen()),
        ),
      ),
    );
  }
}
