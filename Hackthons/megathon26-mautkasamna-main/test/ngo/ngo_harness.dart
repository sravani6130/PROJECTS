import 'package:gullak/core/localization/app_language.dart';
import 'package:gullak/features/ngo/application/ngo_sync.dart';
import 'package:gullak/features/ngo/data/enrolment_repository.dart';
import 'package:gullak/features/ngo/data/ngo_api.dart';
import 'package:gullak/features/ngo/data/outbox_repository.dart';
import 'package:gullak/features/ngo/data/token_store.dart';
import 'package:gullak/features/profiles/data/profile_repository.dart';
import 'package:gullak/features/progress/data/progress_repository.dart';
import 'package:gullak/features/story/data/story_repository.dart';
import 'package:gullak/features/story/domain/story_rules.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/fake_ngo_server.dart';
import '../helpers/test_support.dart';

/// The app's NGO pieces wired together on a real (FFI) SQLite database, as
/// the providers wire them in the app, with a fake server and clock.
class NgoHarness {
  NgoHarness._(this.db, this.server, this.tokens);

  final Database db;
  final FakeNgoServer server;
  final MemoryTokenStore tokens;
  DateTime now = DateTime.utc(2026, 10, 11, 9);

  DateTime clock() => now;
  late final profiles = ProfileRepository(db, clock: clock);
  late final enrolments = EnrolmentRepository(db, clock: clock);
  late final outbox = OutboxRepository(db, clock: clock);
  late final story = StoryRepository(
    db,
    clock: clock,
    onProgressChanged: outbox.recordChange,
  );
  late final progress = ProgressRepository(
    db,
    onProgressChanged: outbox.recordChange,
  );
  late NgoSync sync = syncWith(server.api());

  NgoSync syncWith(NgoApi api) => NgoSync(
    enrolments: enrolments,
    outbox: outbox,
    api: api,
    tokens: tokens,
    clock: clock,
  );

  static Future<NgoHarness> open({
    String path = inMemoryDatabasePath,
    FakeNgoServer? server,
    MemoryTokenStore? tokens,
  }) async => NgoHarness._(
    await openTestDatabase(path: path),
    server ?? FakeNgoServer(),
    tokens ?? MemoryTokenStore(),
  );

  Future<int> newProfile(String name) async => (await profiles.createProfile(
    nickname: name,
    language: AppLanguage.en,
  )).id;

  /// Plays and completes chapter 1 (careful choices) for [profileId].
  Future<void> finishChapterOne(int profileId) async {
    final save = await story.load(profileId);
    var s = StoryRules.apply(save.state, 'c1_budget', {
      'items': ['bus', 'lunch', 'recharge'],
    });
    s = StoryRules.apply(s, 'c1_form', {'option': 'own'});
    await story.completeChapter(
      profileId: profileId,
      chapter: 1,
      stars: s.stars,
      revision: save.revision,
      next: StoryRules.finishChapter(s),
      badgeEvaluator: (done) => done.contains('C1') ? {'budget_planner'} : {},
    );
  }

  /// One in-chapter checkpoint (a beat) for [profileId].
  Future<void> step(int profileId) async {
    final save = await story.load(profileId);
    await story.saveStep(
      profileId,
      save.state.copyWith(beat: save.state.beat + 1),
      save.revision,
    );
  }
}
