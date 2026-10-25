import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../profiles/application/app_session_controller.dart';
import '../data/enrolment_repository.dart';
import '../data/ngo_api.dart';
import '../data/outbox_repository.dart';
import '../data/token_store.dart';
import '../domain/enrolment.dart';
import 'ngo_sync.dart';

/// Overridden in tests with a fake HTTP client.
final ngoApiProvider = Provider<NgoApi>((ref) => NgoApi());

/// Overridden in tests with [MemoryTokenStore].
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final enrolmentRepositoryProvider = Provider(
  (ref) => EnrolmentRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final outboxRepositoryProvider = Provider(
  (ref) => OutboxRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Bumped whenever sync changes something the UI shows.
final _syncTickProvider = NotifierProvider<_SyncTick, int>(_SyncTick.new);

class _SyncTick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final ngoSyncProvider = Provider<NgoSync>((ref) {
  final sync = NgoSync(
    enrolments: ref.watch(enrolmentRepositoryProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    api: ref.watch(ngoApiProvider),
    tokens: ref.watch(tokenStoreProvider),
    clock: ref.watch(clockProvider),
    onChanged: () {
      if (ref.mounted) ref.read(_syncTickProvider.notifier).bump();
    },
  );
  ref.onDispose(sync.syncing.dispose);
  return sync;
});

/// The active profile's NGO link and sync state.
final syncStatusProvider = FutureProvider<SyncStatus>((ref) async {
  ref.watch(_syncTickProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return SyncStatus.notLinked;
  final enrolment = await ref.watch(enrolmentRepositoryProvider).get(profileId);
  final pending = await ref.watch(outboxRepositoryProvider).pending(profileId);
  return SyncStatus.of(
    enrolment,
    hasPending: pending != null,
    syncing: ref.read(ngoSyncProvider).syncing.value,
  );
});

/// Starts a sync when the app opens and each time it returns to the
/// front. Errors never reach the player; progress stays queued.
class NgoSyncTrigger extends ConsumerStatefulWidget {
  const NgoSyncTrigger({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NgoSyncTrigger> createState() => _NgoSyncTriggerState();
}

class _NgoSyncTriggerState extends ConsumerState<NgoSyncTrigger>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  void _sync() {
    if (!mounted) return;
    unawaited(ref.read(ngoSyncProvider).sync().catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
