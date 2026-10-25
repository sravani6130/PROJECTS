import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/audio/narrator.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/game/scenes.dart';
import '../../../core/widgets/gullak_scaffold.dart';
import '../../daily/application/daily_providers.dart';
import '../../daily/data/daily_repository.dart';
import '../../ngo/presentation/ngo_widgets.dart';
import '../../onboarding/presentation/level_select_screen.dart';
import '../../profiles/application/app_session_controller.dart';
import '../../profiles/presentation/profile_form.dart';
import '../../profiles/presentation/profile_picker_screen.dart';
import '../../progress/application/progress_providers.dart';

/// Language switch, profiles, and local data controls.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
    String confirmLabel,
    String cancelLabel,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            key: const ValueKey('confirm_action'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final language = ref.watch(languageProvider);
    final profile = ref.watch(activeProfileProvider);
    final session = ref.read(appSessionProvider.notifier);
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);

    return GullakScaffold(
      title: t('settings_title'),
      scene: SceneKind.home,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('settings_language'), style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.sm),
          SegmentedButton<AppLanguage>(
            key: const ValueKey('language_switch'),
            segments: const [
              ButtonSegment(value: AppLanguage.en, label: Text('English')),
              ButtonSegment(value: AppLanguage.te, label: Text('తెలుగు')),
            ],
            selected: {language},
            onSelectionChanged: (s) => session.selectLanguage(s.single),
          ),
          const SizedBox(height: Gap.xs),
          Text(t('language_keeps_progress'), style: theme.textTheme.bodySmall),
          const Divider(height: Gap.xl),
          Text(t('settings_profile'), style: theme.textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(profile == null ? '' : profileDisplayName(profile, t)),
            subtitle: Text(t('profile_local_only')),
          ),
          if (profile != null) ...[
            const _ReadAloudSetting(),
            const SizedBox(height: Gap.sm),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.switch_account_outlined),
            label: Text(t('switch_profile')),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProfilePickerScreen(),
              ),
            ),
          ),
          const SizedBox(height: Gap.sm),
          OutlinedButton.icon(
            key: const ValueKey('settings_levels'),
            icon: const Icon(Icons.layers_outlined),
            label: Text('${t('levels_open')}: ${t('level_easy')}'),
            onPressed: () => openLevelSelect(context),
          ),
          const Divider(height: Gap.xl),
          const NgoSettingsSection(),
          const Divider(height: Gap.xl),
          const _ReminderSetting(),
          const Divider(height: Gap.xl),
          Text(t('settings_data'), style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.sm),
          OutlinedButton.icon(
            key: const ValueKey('reset_progress'),
            icon: const Icon(Icons.restart_alt),
            label: Text(t('reset_progress')),
            onPressed: () async {
              final ok = await _confirm(
                context,
                t('reset_progress'),
                t('reset_progress_body'),
                t('reset'),
                t('cancel'),
              );
              if (!ok) return;
              await ref.read(progressActionsProvider).resetActiveProfile();
              messenger.showSnackBar(SnackBar(content: Text(t('reset_done'))));
            },
          ),
          const SizedBox(height: Gap.sm),
          OutlinedButton.icon(
            key: const ValueKey('clear_all'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(t('clear_all')),
            onPressed: () async {
              final ok = await _confirm(
                context,
                t('clear_all'),
                t('clear_all_body'),
                t('delete'),
                t('cancel'),
              );
              if (!ok || !context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
              await session.clearAllData();
            },
          ),
          const Divider(height: Gap.xl),
          Text(t('about_title'), style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(t('about_body')),
        ],
      ),
    );
  }
}

/// Speaker switch for reading text aloud, with a slow / normal pace.
class _ReadAloudSetting extends ConsumerStatefulWidget {
  const _ReadAloudSetting();

  @override
  ConsumerState<_ReadAloudSetting> createState() => _ReadAloudSettingState();
}

class _ReadAloudSettingState extends ConsumerState<_ReadAloudSetting> {
  AppLanguage? _checked;
  bool _hasVoice = true;

  /// Asks the phone once per language whether it can speak it, so the
  /// student learns why nothing is heard instead of guessing.
  void _checkVoice(AppLanguage language) {
    if (_checked == language) return;
    _checked = language;
    ref.read(narratorProvider).hasVoice(language).then((ok) {
      if (mounted && _checked == language) setState(() => _hasVoice = ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final readAloud = ref.watch(readAloudProvider);
    final language = ref.watch(languageProvider);
    final session = ref.read(appSessionProvider.notifier);
    final theme = Theme.of(context);
    final on = readAloud.enabled;
    if (on) _checkVoice(language);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              size: 32,
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('settings_read_aloud'),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    t(on ? 'read_aloud_on_note' : 'read_aloud_off_note'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              key: const ValueKey('read_aloud_switch'),
              value: on,
              onChanged: (value) =>
                  session.setReadAloud(value ? ReadAloud.slow : ReadAloud.off),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        if (on) ...[
          SegmentedButton<ReadAloud>(
            key: const ValueKey('read_aloud_pace'),
            segments: [
              ButtonSegment(
                value: ReadAloud.slow,
                label: Text(t('read_aloud_slow')),
              ),
              ButtonSegment(
                value: ReadAloud.normal,
                label: Text(t('read_aloud_normal')),
              ),
            ],
            selected: {readAloud},
            onSelectionChanged: (s) {
              session.setReadAloud(s.single);
              ref
                  .read(narratorProvider)
                  .speak(t('read_aloud_sample'), language, s.single);
            },
          ),
          if (!_hasVoice) ...[
            const SizedBox(height: Gap.xs),
            Text(
              t('read_aloud_no_voice'),
              key: const ValueKey('read_aloud_no_voice'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Daily phone reminder: on/off and the time of day.
class _ReminderSetting extends ConsumerWidget {
  const _ReminderSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final setting =
        ref.watch(reminderSettingProvider).value ?? const ReminderSetting();
    final actions = ref.read(dailyActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final on = setting.enabled;

    Future<void> set(int? hour) async {
      final ok = await actions.setReminderHour(hour);
      if (!ok) {
        messenger.showSnackBar(SnackBar(content: Text(t('reminders_denied'))));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              on
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              size: 32,
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('settings_reminders'),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    t(on ? 'reminders_on_note' : 'reminders_off_note'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              key: const ValueKey('reminder_switch'),
              value: on,
              onChanged: (value) =>
                  set(value ? ReminderSetting.defaultHour : null),
            ),
          ],
        ),
        if (on) ...[
          const SizedBox(height: Gap.sm),
          SegmentedButton<int>(
            key: const ValueKey('reminder_hour'),
            segments: [
              for (final (hour, key) in const [
                (8, 'reminder_morning'),
                (17, 'reminder_after_school'),
                (19, 'reminder_evening'),
              ])
                ButtonSegment(value: hour, label: Text(t(key))),
            ],
            selected: {setting.hour!},
            onSelectionChanged: (s) => set(s.single),
          ),
        ],
      ],
    );
  }
}
