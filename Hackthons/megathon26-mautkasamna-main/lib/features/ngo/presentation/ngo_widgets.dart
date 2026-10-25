import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/game/game_style.dart';
import '../../../core/localization/app_strings.dart';
import '../../profiles/application/app_session_controller.dart';
import '../application/ngo_providers.dart';
import '../domain/enrolment.dart';
import 'ngo_join_screen.dart';

/// "5 min ago" style time.
String agoText(AppStrings t, DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return t('time_just_now');
  if (d.inHours < 1) return t('time_minutes', {'n': d.inMinutes});
  if (d.inDays < 1) return t('time_hours', {'n': d.inHours});
  return t('time_days', {'n': d.inDays});
}

/// Icon, colour and words for a sync state. Never colour alone.
(IconData, Color, String) syncLook(AppStrings t, SyncStatus s, DateTime now) =>
    switch (s.phase) {
      SyncPhase.notLinked => (Icons.link_off_rounded, Colors.grey, ''),
      SyncPhase.waitingToJoin => (
        Icons.schedule_rounded,
        GullakColors.caution,
        t('sync_waiting_join'),
      ),
      SyncPhase.syncing => (Icons.sync_rounded, Toon.teal, t('sync_syncing')),
      SyncPhase.pending => (
        Icons.cloud_upload_rounded,
        GullakColors.caution,
        t('sync_pending'),
      ),
      SyncPhase.offline => (
        Icons.cloud_off_rounded,
        GullakColors.caution,
        t('sync_offline'),
      ),
      SyncPhase.synced => (
        Icons.cloud_done_rounded,
        GullakColors.success,
        s.lastSyncedAt == null
            ? t('sync_synced_never')
            : t('sync_synced', {'time': agoText(t, s.lastSyncedAt!, now)}),
      ),
      SyncPhase.actionNeeded => (
        Icons.error_outline_rounded,
        Toon.berry,
        t('sync_action'),
      ),
      SyncPhase.unlinking => (
        Icons.link_off_rounded,
        GullakColors.caution,
        t('ngo_unlinking'),
      ),
    };

/// Small sync badge for the map's HUD. Hidden when not linked to an NGO.
class SyncChip extends ConsumerWidget {
  const SyncChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value;
    if (status == null || status.phase == SyncPhase.notLinked) {
      return const SizedBox.shrink();
    }
    final t = ref.watch(stringsProvider);
    final (icon, color, label) = syncLook(t, status, ref.read(clockProvider)());
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        key: ValueKey('sync_chip_${status.phase.name}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.1, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings → My NGO: link status, sync now, join, unlink.
class NgoSettingsSection extends ConsumerWidget {
  const NgoSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final status = ref.watch(syncStatusProvider).value ?? SyncStatus.notLinked;
    final e = status.enrolment;
    final sync = ref.read(ngoSyncProvider);
    final profileId = ref.watch(activeProfileIdProvider);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> unlink() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t('ngo_unlink')),
          content: Text(t('ngo_unlink_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t('cancel')),
            ),
            FilledButton(
              key: const ValueKey('confirm_unlink'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t('ngo_unlink_confirm')),
            ),
          ],
        ),
      );
      if (ok != true || profileId == null) return;
      await sync.unlink(profileId).catchError((Object _) {});
      messenger.showSnackBar(SnackBar(content: Text(t('ngo_unlinked'))));
    }

    final (icon, color, label) = syncLook(t, status, ref.read(clockProvider)());
    return Column(
      key: const ValueKey('ngo_settings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('settings_ngo'), style: theme.textTheme.titleMedium),
        const SizedBox(height: Gap.xs),
        if (e == null) ...[
          Text(t('ngo_not_linked')),
          const SizedBox(height: Gap.sm),
          OutlinedButton.icon(
            key: const ValueKey('ngo_open_join'),
            icon: const Icon(Icons.link_rounded),
            label: Text(t('ngo_open_join')),
            onPressed: () => openNgoJoin(context),
          ),
        ] else ...[
          if (e.ngoName != null)
            Text(
              t('ngo_linked_to', {
                'ngo': e.ngoName!,
                'centre': e.centreName ?? '',
              }),
              key: const ValueKey('ngo_linked_name'),
              style: theme.textTheme.titleSmall,
            ),
          if (e.studentId != null)
            SelectableText(t('ngo_student_id', {'id': e.studentId!})),
          if (e.status == EnrolmentStatus.pending)
            Text(t('ngo_pending_join', {'code': e.code})),
          if (e.status == EnrolmentStatus.rejected)
            Text(
              t('ngo_rejected', {'code': e.code}),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          if (e.status == EnrolmentStatus.revoked)
            Text(
              t('ngo_revoked'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          const SizedBox(height: Gap.xs),
          Row(
            key: const ValueKey('ngo_sync_state'),
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Text(label, style: TextStyle(color: color)),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          if (e.needsAction)
            OutlinedButton.icon(
              key: const ValueKey('ngo_new_code'),
              icon: const Icon(Icons.edit_rounded),
              label: Text(t('ngo_new_code')),
              onPressed: () => openNgoJoin(context),
            )
          else if (e.status != EnrolmentStatus.unlinking)
            OutlinedButton.icon(
              key: const ValueKey('ngo_sync_now'),
              icon: const Icon(Icons.sync_rounded),
              label: Text(t('ngo_sync_now')),
              onPressed: status.phase == SyncPhase.syncing
                  ? null
                  : () => sync.sync(force: true).catchError((Object _) {}),
            ),
          if (e.status != EnrolmentStatus.unlinking) ...[
            const SizedBox(height: Gap.sm),
            OutlinedButton.icon(
              key: const ValueKey('ngo_unlink'),
              icon: const Icon(Icons.link_off_rounded),
              label: Text(t('ngo_unlink')),
              onPressed: unlink,
            ),
          ],
        ],
      ],
    );
  }
}
