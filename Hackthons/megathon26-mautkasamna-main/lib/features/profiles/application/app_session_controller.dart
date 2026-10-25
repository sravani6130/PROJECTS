import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/audio/narrator.dart';
import '../../../core/localization/app_language.dart';
import '../../ngo/application/ngo_providers.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// Who is playing, in which language, and whether onboarding is finished.
class AppSession {
  const AppSession({
    required this.language,
    required this.onboardingDone,
    required this.profiles,
    this.activeProfile,
    this.needsProfilePick = false,
  });

  final AppLanguage language;

  /// True once the student has seen the pretend-money notice, chosen a
  /// profile (or guest) and picked a level.
  final bool onboardingDone;
  final List<Profile> profiles;
  final Profile? activeProfile;

  /// On a shared device with several profiles, ask who is playing at launch.
  final bool needsProfilePick;

  bool get readyForHome =>
      onboardingDone && activeProfile != null && !needsProfilePick;
}

final appSessionProvider =
    AsyncNotifierProvider<AppSessionController, AppSession>(
      AppSessionController.new,
    );

final activeProfileProvider = Provider<Profile?>(
  (ref) => ref.watch(appSessionProvider).value?.activeProfile,
);

/// Only the id, so progress reloads when the player changes—not on every
/// session update such as a language switch.
final activeProfileIdProvider = Provider<int?>(
  (ref) => ref.watch(activeProfileProvider)?.id,
);

class AppSessionController extends AsyncNotifier<AppSession> {
  ProfileRepository get _profiles => ref.read(profileRepositoryProvider);

  @override
  Future<AppSession> build() => _load(atLaunch: true);

  Future<AppSession> _load({required bool atLaunch}) async {
    final app = await _profiles.loadAppState();
    final profiles = await _profiles.listProfiles();
    Profile? active;
    for (final p in profiles) {
      if (p.id == app.activeProfileId) active = p;
    }
    return AppSession(
      language: active?.language ?? app.language,
      onboardingDone: app.noticeAccepted,
      profiles: profiles,
      activeProfile: active,
      needsProfilePick: atLaunch && app.noticeAccepted && profiles.length > 1,
    );
  }

  Future<void> _refresh() async {
    final next = await _load(atLaunch: false);
    if (ref.mounted) state = AsyncData(next);
  }

  Future<void> selectLanguage(AppLanguage language) async {
    await _profiles.setLanguage(
      language,
      profileId: state.value?.activeProfile?.id,
    );
    await _refresh();
  }

  /// Turns reading aloud on or off (or changes its pace) for the active
  /// profile.
  Future<void> setReadAloud(ReadAloud readAloud) async {
    final profile = state.value?.activeProfile;
    if (profile == null) return;
    if (!readAloud.enabled) await ref.read(narratorProvider).stop();
    await _profiles.setReadAloud(profile.id, readAloud);
    await _refresh();
  }

  /// Creates a nickname profile and makes it active. A blank nickname
  /// continues as guest. Throws [DuplicateNicknameException].
  Future<void> createProfile({
    required String? nickname,
    int? grade,
    String? avatarId,
  }) async {
    final profile = await _profiles.createProfile(
      nickname: nickname,
      language: state.value?.language ?? AppLanguage.en,
      grade: grade,
      avatarId: avatarId,
    );
    await _activate(profile);
  }

  Future<void> continueAsGuest() async {
    final guest = await _profiles.getOrCreateGuest(
      state.value?.language ?? AppLanguage.en,
    );
    await _activate(guest);
  }

  Future<void> switchProfile(int profileId) async {
    final profile = await _profiles.getProfile(profileId);
    if (profile == null) return;
    await _activate(profile);
  }

  Future<void> _activate(Profile profile) async {
    await _profiles.setActiveProfile(profile.id);
    // Keep the device language in step with the chosen profile.
    await _profiles.setLanguage(profile.language);
    await _refresh();
  }

  Future<void> completeOnboarding() async {
    await _profiles.acceptNotice();
    await _refresh();
  }

  /// Records that the active profile was asked for an NGO code (joined or
  /// skipped), so the question is not asked again.
  Future<void> markNgoPrompted() async {
    final profile = state.value?.activeProfile;
    if (profile == null) return;
    await _profiles.markNgoPromptDone(profile.id);
    await _refresh();
  }

  /// Removes every profile and all progress, returning to the welcome screen.
  /// Linked NGOs are asked to delete their copy first (when online) and
  /// every stored token is erased.
  Future<void> clearAllData() async {
    await ref.read(ngoSyncProvider).forgetAll();
    await _profiles.clearAllData();
    // Progress reloads by itself because the active profile becomes null.
    await _refresh();
  }
}
