import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../ngo/application/ngo_providers.dart';
import '../../profiles/application/app_session_controller.dart';
import '../domain/progress_models.dart';

/// Progress for the active profile. Invalidate after any progress write.
final progressSnapshotProvider = FutureProvider<ProgressSnapshot>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return ProgressSnapshot.empty;
  return ref.watch(progressRepositoryProvider).loadSnapshot(profileId);
});

final progressActionsProvider = Provider(ProgressActions.new);

/// Progress writes that are not part of a mission or study pack.
class ProgressActions {
  ProgressActions(this._ref);

  final Ref _ref;

  /// Clears the active profile's progress only; other profiles are untouched.
  Future<void> resetActiveProfile() async {
    final profileId = _ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    await _ref.read(progressRepositoryProvider).resetProfileProgress(profileId);
    _ref.invalidate(progressSnapshotProvider);
    _ref.invalidate(syncStatusProvider);
  }
}
