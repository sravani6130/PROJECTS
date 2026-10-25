import 'package:sqflite/sqflite.dart';

import '../../../core/audio/narrator.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/utils/ids.dart';
import '../../content/domain/content_models.dart';
import '../domain/profile.dart';

/// Thrown when a nickname is already used by another local profile.
class DuplicateNicknameException implements Exception {
  DuplicateNicknameException(this.nickname);

  final String nickname;
}

/// Local profiles (PROFILE) and device state (APP_STATE).
class ProfileRepository {
  ProfileRepository(this._db, {Clock? clock}) : _clock = clock ?? DateTime.now;

  final Database _db;
  final Clock _clock;

  String get _now => isoNow(_clock);

  // --- App state -----------------------------------------------------------

  Future<AppState> loadAppState() async {
    final rows = await _db.query('app_state', where: 'id = 1');
    if (rows.isEmpty) {
      return const AppState(language: AppLanguage.en, noticeAccepted: false);
    }
    final row = rows.single;
    return AppState(
      language: AppLanguage.fromCode(row['locale'] as String?),
      noticeAccepted: row['notice_accepted'] == 1,
      activeProfileId: row['active_profile_id'] as int?,
    );
  }

  Future<void> _upsertAppState(
    DatabaseExecutor db,
    Map<String, Object?> values,
  ) async {
    final updated = await db.update('app_state', {
      ...values,
      'updated_at': _now,
    }, where: 'id = 1');
    if (updated == 0) {
      await db.insert('app_state', {'id': 1, ...values, 'updated_at': _now});
    }
  }

  /// Saves the device language and, if given, the active profile's language,
  /// so switching never touches progress rows.
  Future<void> setLanguage(AppLanguage language, {int? profileId}) {
    return _db.transaction((txn) async {
      await _upsertAppState(txn, {'locale': language.code});
      if (profileId != null) {
        await txn.update(
          'profile',
          {'locale': language.code},
          where: 'profile_id = ?',
          whereArgs: [profileId],
        );
      }
    });
  }

  Future<void> acceptNotice() => _upsertAppState(_db, {'notice_accepted': 1});

  Future<void> setActiveProfile(int profileId) {
    return _db.transaction((txn) async {
      await _upsertAppState(txn, {'active_profile_id': profileId});
      await txn.update(
        'profile',
        {'last_active_at': _now},
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
    });
  }

  Future<void> setReadAloud(int profileId, ReadAloud readAloud) => _db.update(
    'profile',
    {'read_aloud': readAloud.name},
    where: 'profile_id = ?',
    whereArgs: [profileId],
  );

  Future<void> markNgoPromptDone(int profileId) => _db.update(
    'profile',
    {'ngo_prompt_done': 1},
    where: 'profile_id = ?',
    whereArgs: [profileId],
  );

  // --- Profiles ------------------------------------------------------------

  Future<List<Profile>> listProfiles() async {
    final rows = await _db.query(
      'profile',
      orderBy: 'is_guest DESC, last_active_at DESC',
    );
    return rows.map(_toProfile).toList();
  }

  Future<Profile?> getProfile(int profileId) async {
    final rows = await _db.query(
      'profile',
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    return rows.isEmpty ? null : _toProfile(rows.single);
  }

  /// Returns the single guest profile, creating it on first use.
  Future<Profile> getOrCreateGuest(AppLanguage language) async {
    final existing = await _db.query('profile', where: 'is_guest = 1');
    if (existing.isNotEmpty) return _toProfile(existing.single);
    final id = await _db.insert('profile', {
      'is_guest': 1,
      'locale': language.code,
      'start_level': Difficulty.easy.name,
      'created_at': _now,
      'last_active_at': _now,
    });
    return (await getProfile(id))!;
  }

  /// Creates a named profile. A blank nickname falls back to the guest
  /// profile; a long one is trimmed to [Profile.maxNicknameLength].
  Future<Profile> createProfile({
    required String? nickname,
    required AppLanguage language,
    int? grade,
    String? avatarId,
  }) async {
    final name = Profile.normaliseNickname(nickname);
    if (name == null) return getOrCreateGuest(language);
    if (grade != null && !Profile.allowedGrades.contains(grade)) {
      throw ArgumentError.value(grade, 'grade', 'must be 11 or 12');
    }
    if (avatarId != null && !Profile.avatarIds.contains(avatarId)) {
      throw ArgumentError.value(avatarId, 'avatarId', 'unknown avatar');
    }
    try {
      final id = await _db.insert('profile', {
        'nickname': name,
        'is_guest': 0,
        'grade': grade,
        'avatar_id': avatarId,
        'locale': language.code,
        'start_level': Difficulty.easy.name,
        'created_at': _now,
        'last_active_at': _now,
      });
      return (await getProfile(id))!;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw DuplicateNicknameException(name);
      }
      rethrow;
    }
  }

  /// Deletes one profile; its progress cascades away. Other profiles are
  /// untouched.
  Future<void> deleteProfile(int profileId) =>
      _db.delete('profile', where: 'profile_id = ?', whereArgs: [profileId]);

  /// Removes every profile, all progress and device state.
  Future<void> clearAllData() {
    return _db.transaction((txn) async {
      // Children first; cascades would handle most, but being explicit keeps
      // this correct even if a future table forgets ON DELETE CASCADE.
      for (final table in const [
        'sync_outbox',
        'ngo_enrolment',
        'story_save',
        'daily_checkin',
        'inbox',
        'attempt_decision',
        'attempt',
        'mission_progress',
        'study_progress',
        'assessment_result',
        'badge_award',
        'app_state',
        'profile',
      ]) {
        await txn.delete(table);
      }
    });
  }

  Profile _toProfile(Map<String, Object?> row) => Profile(
    id: row['profile_id']! as int,
    isGuest: row['is_guest'] == 1,
    nickname: row['nickname'] as String?,
    grade: row['grade'] as int?,
    avatarId: row['avatar_id'] as String?,
    language: AppLanguage.fromCode(row['locale'] as String?),
    startLevel: Difficulty.values.byName(row['start_level']! as String),
    readAloud: ReadAloud.fromCode(row['read_aloud'] as String?),
    ngoPromptDone: row['ngo_prompt_done'] == 1,
  );
}
