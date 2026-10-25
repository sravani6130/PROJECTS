import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/game/characters.dart';
import '../../../core/game/game_style.dart';
import '../../../core/game/game_widgets.dart';
import '../../../core/game/scenes.dart';
import '../../../core/widgets/gullak_scaffold.dart';
import '../../profiles/application/app_session_controller.dart';
import '../application/ngo_providers.dart';
import '../application/ngo_sync.dart';
import '../data/ngo_api.dart';
import '../domain/enrolment.dart';

void openNgoJoin(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const NgoJoinScreen()));

enum _Check { idle, checking, found, offline, error }

/// Asks for the NGO enrolment code: check it, show which organisation it
/// belongs to and what will be shared, then join with the student's
/// consent. Shown once per new profile ([firstRun]) and from Settings.
class NgoJoinScreen extends ConsumerStatefulWidget {
  const NgoJoinScreen({super.key, this.firstRun = false});

  /// True when shown by the app after creating a profile: "Skip for now"
  /// is offered and finishing returns to the map instead of popping.
  final bool firstRun;

  @override
  ConsumerState<NgoJoinScreen> createState() => _NgoJoinScreenState();
}

class _NgoJoinScreenState extends ConsumerState<NgoJoinScreen> {
  final _code = TextEditingController();
  _Check _check = _Check.idle;
  CodeInfo? _info;
  String? _errorKey;
  bool _consent = false;
  bool _joining = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _normalised => normaliseEnrolmentCode(_code.text);

  Future<void> _checkCode() async {
    FocusScope.of(context).unfocus();
    if (!enrolmentCodePattern.hasMatch(_normalised)) {
      setState(() {
        _check = _Check.error;
        _errorKey = 'ngo_code_format';
      });
      return;
    }
    setState(() {
      _check = _Check.checking;
      _errorKey = null;
      _consent = false;
    });
    try {
      final info = await ref.read(ngoSyncProvider).checkCode(_normalised);
      if (!mounted) return;
      setState(() {
        _check = _Check.found;
        _info = info;
      });
    } on NgoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _check = switch (e.failure) {
          ApiFailure.offline => _Check.offline,
          _ => _Check.error,
        };
        _errorKey = switch (e.code) {
          'code_not_found' => 'ngo_code_not_found',
          'code_revoked' => 'ngo_code_revoked',
          'invalid_request' => 'ngo_code_format',
          _ => e.failure == ApiFailure.server ? 'ngo_server_busy' : null,
        };
        // The server is busy, not the code: allow saving it for later.
        if (e.failure == ApiFailure.server) _check = _Check.offline;
      });
    }
  }

  Future<void> _join() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null || !_consent || _joining) return;
    setState(() => _joining = true);
    final t = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(ngoSyncProvider)
        .join(profileId, _normalised);
    if (!mounted) return;
    setState(() => _joining = false);
    switch (outcome) {
      case JoinOutcome.invalidCode || JoinOutcome.revokedCode:
        setState(() {
          _check = _Check.error;
          _errorKey = outcome == JoinOutcome.revokedCode
              ? 'ngo_code_revoked'
              : 'ngo_code_not_found';
        });
        return;
      case JoinOutcome.joined:
        final e = await ref.read(enrolmentRepositoryProvider).get(profileId);
        messenger.showSnackBar(
          SnackBar(content: Text(t('ngo_joined', {'ngo': e?.ngoName ?? ''}))),
        );
      case JoinOutcome.savedOffline || JoinOutcome.serverBusy:
        messenger.showSnackBar(
          SnackBar(
            content: Text(t('ngo_saved_offline', {'code': _normalised})),
          ),
        );
    }
    await _finish();
  }

  Future<void> _finish() async {
    ref.invalidate(syncStatusProvider);
    if (widget.firstRun) {
      await ref.read(appSessionProvider.notifier).markNgoPrompted();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final canJoin = _check == _Check.found || _check == _Check.offline;

    return GullakScaffold(
      title: t('ngo_title'),
      scene: SceneKind.classroom,
      showBack: !widget.firstRun,
      header: SizedBox(
        height: 130,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 90, child: GullakMascot(talking: true)),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SpeechBubble(text: t('ngo_heading')),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('ngo_body'), style: theme.textTheme.bodyLarge),
          const SizedBox(height: Gap.md),
          TextField(
            key: const ValueKey('ngo_code_field'),
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 24,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9- ]')),
            ],
            decoration: InputDecoration(
              labelText: t('ngo_code_label'),
              hintText: t('ngo_code_hint'),
              border: const OutlineInputBorder(),
              counterText: '',
            ),
            onChanged: (_) {
              if (_check != _Check.idle) {
                setState(() {
                  _check = _Check.idle;
                  _consent = false;
                });
              }
            },
            onSubmitted: (_) => _checkCode(),
          ),
          const SizedBox(height: Gap.sm),
          OutlinedButton.icon(
            key: const ValueKey('ngo_check'),
            icon: _check == _Check.checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(
              t(_check == _Check.checking ? 'ngo_checking' : 'ngo_check'),
            ),
            onPressed: _check == _Check.checking ? null : _checkCode,
          ),
          if (_check == _Check.error && _errorKey != null) ...[
            const SizedBox(height: Gap.sm),
            _Note(
              key: const ValueKey('ngo_error'),
              icon: Icons.error_outline_rounded,
              color: theme.colorScheme.error,
              text: t(_errorKey!),
            ),
          ],
          if (_check == _Check.offline) ...[
            const SizedBox(height: Gap.sm),
            _Note(
              key: const ValueKey('ngo_offline'),
              icon: Icons.wifi_off_rounded,
              color: Toon.teal,
              text: t(_errorKey ?? 'ngo_offline_check'),
            ),
          ],
          if (_check == _Check.found && _info != null) ...[
            const SizedBox(height: Gap.md),
            Container(
              key: const ValueKey('ngo_found'),
              padding: const EdgeInsets.all(Gap.md),
              decoration: toonPanel(color: Colors.white, radius: 16, shadow: 3),
              child: Row(
                children: [
                  const Icon(
                    Icons.volunteer_activism_rounded,
                    color: Toon.leafDark,
                    size: 32,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('ngo_found'), style: theme.textTheme.bodySmall),
                        Text(
                          _info!.ngoName,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(_info!.centreName),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (canJoin) ...[
            const SizedBox(height: Gap.md),
            const NgoSharingNotice(),
            const SizedBox(height: Gap.sm),
            // Own Material: the cartoon panel would hide the ink otherwise.
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                key: const ValueKey('ngo_consent'),
                value: _consent,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(t('ngo_consent')),
                onChanged: (v) => setState(() => _consent = v ?? false),
              ),
            ),
          ],
          if (widget.firstRun) ...[
            const SizedBox(height: Gap.sm),
            Text(t('ngo_skip_note'), style: theme.textTheme.bodySmall),
          ],
        ],
      ),
      // Stacked, so long Telugu labels fit on small phones.
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GameButton(
            key: const ValueKey('ngo_join'),
            label: t(_check == _Check.offline ? 'ngo_save_code' : 'ngo_join'),
            icon: Icons.link_rounded,
            busy: _joining,
            onPressed: canJoin && _consent ? _join : null,
          ),
          if (widget.firstRun)
            TextButton(
              key: const ValueKey('ngo_skip'),
              onPressed: _joining ? null : _finish,
              child: Text(t('ngo_skip')),
            ),
        ],
      ),
    );
  }
}

/// What the NGO receives, what it never receives, and how to stop.
class NgoSharingNotice extends ConsumerWidget {
  const NgoSharingNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    const points = [
      (Icons.check_circle_rounded, Toon.leafDark, 'ngo_share_yes'),
      (Icons.block_rounded, Toon.berry, 'ngo_share_no'),
      (Icons.wifi_rounded, Toon.teal, 'ngo_share_when'),
      (Icons.link_off_rounded, Toon.clay, 'ngo_share_stop'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('ngo_shared_title'), style: theme.textTheme.titleSmall),
        const SizedBox(height: Gap.xs),
        for (final (icon, color, key) in points)
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(t(key), style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: Gap.sm),
      Expanded(
        child: Text(text, style: TextStyle(color: color)),
      ),
    ],
  );
}
