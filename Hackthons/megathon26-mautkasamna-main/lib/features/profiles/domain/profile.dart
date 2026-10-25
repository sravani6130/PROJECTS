import '../../../core/audio/narrator.dart';
import '../../../core/localization/app_language.dart';
import '../../content/domain/content_models.dart';

/// A local, device-only learner profile. Holds no real personal or financial
/// data: nickname, grade and avatar are all optional.
class Profile {
  const Profile({
    required this.id,
    required this.isGuest,
    required this.language,
    required this.startLevel,
    this.nickname,
    this.grade,
    this.avatarId,
    this.readAloud = ReadAloud.slow,
    this.ngoPromptDone = false,
  });

  static const maxNicknameLength = 20;
  static const allowedGrades = {11, 12};
  static const avatarIds = ['star', 'rocket', 'leaf', 'book', 'music', 'bolt'];

  final int id;
  final bool isGuest;
  final String? nickname;
  final int? grade;
  final String? avatarId;
  final AppLanguage language;
  final Difficulty startLevel;

  /// Whether story text is read out, and how fast.
  final ReadAloud readAloud;

  /// True once this profile has been asked for an NGO code (joined or
  /// skipped). The question is asked once per profile.
  final bool ngoPromptDone;

  /// Trims a nickname and caps its length. Returns null for blank input, which
  /// callers treat as "continue as guest".
  static String? normaliseNickname(String? raw) {
    final trimmed = raw?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.length <= maxNicknameLength
        ? trimmed
        : trimmed.substring(0, maxNicknameLength).trimRight();
  }
}

/// Device-level state: chosen language before a profile exists, whether the
/// pretend-money notice was accepted, and the active profile.
class AppState {
  const AppState({
    required this.language,
    required this.noticeAccepted,
    this.activeProfileId,
  });

  final AppLanguage language;
  final bool noticeAccepted;
  final int? activeProfileId;

  bool get onboarded => noticeAccepted && activeProfileId != null;
}
