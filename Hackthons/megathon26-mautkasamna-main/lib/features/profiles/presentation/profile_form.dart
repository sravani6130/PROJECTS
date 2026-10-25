import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/game/characters.dart';
import '../../../core/game/game_style.dart';
import '../../../core/game/game_widgets.dart';
import '../../../core/game/scenes.dart';
import '../../../core/widgets/gullak_scaffold.dart';
import '../application/app_session_controller.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

String profileDisplayName(Profile profile, AppStrings t) =>
    profile.isGuest ? t('guest') : profile.nickname!;

/// Optional nickname-only profile, with "Continue as guest". Never asks for
/// a real name, contact details, school or any financial information.
class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({
    super.key,
    this.showExistingProfiles = false,
    this.onDone,
    this.onBack,
  });

  final bool showExistingProfiles;

  /// Called after a profile becomes active. When null (opened as a route),
  /// the screen returns to the first route instead.
  final VoidCallback? onDone;
  final VoidCallback? onBack;

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _nickname = TextEditingController();
  int? _grade;
  String? _avatar;
  String? _errorKey;
  bool _saving = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  void _finish() {
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _run(
    Future<void> Function(AppSessionController c) action,
  ) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorKey = null;
    });
    try {
      await action(ref.read(appSessionProvider.notifier));
      _finish();
    } on DuplicateNicknameException {
      setState(() => _errorKey = 'profile_name_taken');
    } on Object {
      setState(() => _errorKey = 'error_save');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final existing = widget.showExistingProfiles
        ? ref.watch(appSessionProvider).value?.profiles ?? const <Profile>[]
        : const <Profile>[];

    return GullakScaffold(
      title: t('profile_title'),
      scene: SceneKind.home,
      onBack: widget.onBack,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (existing.isNotEmpty) ...[
            Text(t('profile_existing'), style: theme.textTheme.titleMedium),
            const SizedBox(height: Gap.sm),
            for (final p in existing)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: GameButton(
                  style: GameButtonStyle.plain,
                  icon: Icons.person_rounded,
                  label: t('continue_as', {'name': profileDisplayName(p, t)}),
                  onPressed: () => _run((c) => c.switchProfile(p.id)),
                ),
              ),
            const Divider(height: Gap.xl),
          ],
          Text(t('profile_body'), style: theme.textTheme.bodyLarge),
          const SizedBox(height: Gap.md),
          TextField(
            key: const ValueKey('nickname_field'),
            controller: _nickname,
            maxLength: Profile.maxNicknameLength,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: t('profile_nickname'),
              helperText: t('profile_nickname_help'),
              errorText: _errorKey == null ? null : t(_errorKey!),
            ),
          ),
          const SizedBox(height: Gap.md),
          Text(t('profile_grade'), style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            children: [
              for (final grade in Profile.allowedGrades)
                ChoiceChip(
                  label: Text(t('grade_n', {'grade': grade})),
                  selected: _grade == grade,
                  onSelected: (on) =>
                      setState(() => _grade = on ? grade : null),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(t('profile_avatar'), style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final (i, id) in Profile.avatarIds.indexed)
                AvatarChoice(
                  look: CharacterLook.avatars[id]!,
                  label: t('avatar_n', {'n': i + 1}),
                  selected: _avatar == id,
                  onTap: () =>
                      setState(() => _avatar = _avatar == id ? null : id),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(child: Text(t('profile_privacy'))),
            ],
          ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameButton(
            key: const ValueKey('profile_save'),
            label: t('profile_save'),
            icon: Icons.check_rounded,
            busy: _saving,
            onPressed: _saving
                ? null
                : () => _run(
                    (c) => c.createProfile(
                      nickname: _nickname.text,
                      grade: _grade,
                      avatarId: _avatar,
                    ),
                  ),
          ),
          const SizedBox(height: Gap.sm),
          GameButton(
            key: const ValueKey('profile_guest'),
            label: t('continue_guest'),
            style: GameButtonStyle.plain,
            onPressed: _saving ? null : () => _run((c) => c.continueAsGuest()),
          ),
        ],
      ),
    );
  }
}

/// Selectable cartoon face used as a profile avatar.
class AvatarChoice extends StatelessWidget {
  const AvatarChoice({
    super.key,
    required this.look,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final CharacterLook look;
  final String label;
  final bool selected;
  final VoidCallback onTap;

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
          duration: const Duration(milliseconds: 150),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? Toon.gold : const Color(0xFFBFE8FF),
            border: Border.all(color: Toon.ink, width: selected ? 4 : 2.5),
          ),
          child: ClipOval(child: CartoonFace(look: look)),
        ),
      ),
    );
  }
}
