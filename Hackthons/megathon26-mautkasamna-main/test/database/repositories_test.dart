import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/core/localization/app_language.dart';
import 'package:gullak/features/profiles/data/profile_repository.dart';
import 'package:gullak/features/progress/data/progress_repository.dart';
import 'package:gullak/features/story/data/story_repository.dart';
import 'package:gullak/features/story/domain/story_rules.dart';
import 'package:gullak/features/story/domain/story_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_support.dart';

void main() {
  late Database db;
  late ProfileRepository profiles;
  late StoryRepository story;
  late ProgressRepository progress;

  setUp(() async {
    db = await openTestDatabase();
    DateTime clock() => DateTime.utc(2026, 10, 10, 12);
    profiles = ProfileRepository(db, clock: clock);
    story = StoryRepository(db, clock: clock);
    progress = ProgressRepository(db);
  });
  tearDown(() => db.close());

  Set<String> badgeRule(Set<String> completed) =>
      completed.contains('C1') ? {'budget_planner'} : {};

  /// Plays chapter 1 to its end for [profileId] and records it.
  Future<StorySave> finishChapterOne(int profileId) async {
    final save = await story.load(profileId);
    final played = StoryRules.apply(save.state, 'c1_budget', {
      'items': ['bus', 'lunch', 'recharge'],
    });
    await story.completeChapter(
      profileId: profileId,
      chapter: 1,
      stars: played.stars,
      revision: save.revision,
      next: StoryRules.finishChapter(played),
      badgeEvaluator: badgeRule,
    );
    return story.load(profileId);
  }

  group('profiles', () {
    test('create, load, switch and update language', () async {
      final asha = await profiles.createProfile(
        nickname: '  Asha  ',
        language: AppLanguage.te,
        grade: 11,
        avatarId: 'star',
      );
      expect(asha.nickname, 'Asha');
      expect(asha.grade, 11);
      expect(asha.language, AppLanguage.te);

      await profiles.setActiveProfile(asha.id);
      await profiles.setLanguage(AppLanguage.en, profileId: asha.id);
      final state = await profiles.loadAppState();
      expect(state.activeProfileId, asha.id);
      expect(state.language, AppLanguage.en);
      expect((await profiles.getProfile(asha.id))!.language, AppLanguage.en);
    });

    test('blank nickname falls back to the single guest profile', () async {
      final a = await profiles.createProfile(
        nickname: '   ',
        language: AppLanguage.en,
      );
      final b = await profiles.getOrCreateGuest(AppLanguage.en);
      expect(a.isGuest, isTrue);
      expect(b.id, a.id);
    });

    test('long nicknames are trimmed to 20 characters', () async {
      final p = await profiles.createProfile(
        nickname: 'A' * 40,
        language: AppLanguage.en,
      );
      expect(p.nickname!.length, 20);
    });

    test('duplicate nickname is reported', () async {
      await profiles.createProfile(nickname: 'Ravi', language: AppLanguage.en);
      await expectLater(
        profiles.createProfile(nickname: 'ravi', language: AppLanguage.en),
        throwsA(isA<DuplicateNicknameException>()),
      );
    });

    test('notice acceptance persists', () async {
      expect((await profiles.loadAppState()).noticeAccepted, isFalse);
      await profiles.acceptNotice();
      expect((await profiles.loadAppState()).noticeAccepted, isTrue);
    });
  });

  group('story save', () {
    test('a new profile starts chapter 1 with the pocket money', () async {
      final p = await profiles.getOrCreateGuest(AppLanguage.en);
      final save = await story.load(p.id);
      expect(save.state.chapter, 1);
      expect(save.state.wallet, StoryRules.pocketMoney);
      expect(save.revision, 0);
      expect(save.starts.keys, [1]);
      // Loading again returns the same story instead of a second one.
      expect((await story.load(p.id)).state.txns, hasLength(1));
      expect(await db.query('story_save'), hasLength(1));
    });

    test('a checkpoint round-trips every field', () async {
      final p = await profiles.getOrCreateGuest(AppLanguage.en);
      final save = await story.load(p.id);
      final next = StoryRules.apply(save.state, 'c1_budget', {
        'items': ['bus', 'lunch', 'recharge', 'movie'],
      }).copyWith(beat: 2);
      final revision = await story.saveStep(p.id, next, save.revision);
      expect(revision, 1);
      final loaded = await story.load(p.id);
      expect(loaded.revision, 1);
      expect(loaded.state.encode(), next.encode());
      expect(loaded.state.wallet, 200);
      expect(loaded.state.beat, 2);
      expect(loaded.state.flags, {'c1_movie': '1'});
    });

    test('a second save from the same revision is rejected', () async {
      final p = await profiles.getOrCreateGuest(AppLanguage.en);
      final save = await story.load(p.id);
      final spent = StoryRules.apply(save.state, 'c1_budget', {
        'items': ['bus', 'lunch', 'recharge'],
      });
      await story.saveStep(p.id, spent, save.revision);
      // A double tap would try to save from the old revision again.
      await expectLater(
        story.saveStep(p.id, spent, save.revision),
        throwsA(isA<StaleStoryException>()),
      );
      expect((await story.load(p.id)).state.wallet, 400);
      expect((await story.load(p.id)).revision, 1);
    });

    test('finishing a chapter moves the story on in one step', () async {
      final p = await profiles.getOrCreateGuest(AppLanguage.en);
      final after = await finishChapterOne(p.id);
      expect(after.state.chapter, 2);
      expect(after.state.done.keys, [1]);
      // ₹400 left over plus the ₹100 gift that opens chapter 2.
      expect(after.state.jar, 500);
      expect(after.starts.keys.toSet(), {1, 2});
      expect(after.starts[1]!.wallet, StoryRules.pocketMoney);

      final snapshot = await progress.loadSnapshot(p.id);
      expect(snapshot.mission('C1').isCompleted, isTrue);
      expect(snapshot.badgeIds, {'budget_planner'});
    });

    test('a chapter cannot be finished twice from the same save', () async {
      final p = await profiles.getOrCreateGuest(AppLanguage.en);
      final save = await story.load(p.id);
      Future<void> finish() => story.completeChapter(
        profileId: p.id,
        chapter: 1,
        stars: 3,
        revision: save.revision,
        next: StoryRules.finishChapter(save.state),
        badgeEvaluator: badgeRule,
      );
      await finish();
      await expectLater(finish(), throwsA(isA<StaleStoryException>()));
      // The rejected call rolled back completely.
      final row = (await db.query('mission_progress')).single;
      expect(row['completion_count'], 1);
      expect((await story.load(p.id)).state.jar, 1100);
    });

    test('a practice replay keeps the saved story untouched', () async {
      final p = await profiles.getOrCreateGuest(AppLanguage.en);
      final before = await finishChapterOne(p.id);
      final result = await story.completeChapter(
        profileId: p.id,
        chapter: 1,
        stars: 2,
        revision: before.revision,
        badgeEvaluator: badgeRule,
      );
      expect(result.badges, isEmpty);
      final after = await story.load(p.id);
      expect(after.revision, before.revision);
      expect(after.state.encode(), before.state.encode());
      final row = (await db.query('mission_progress')).single;
      expect(row['completion_count'], 2);
      expect(row['best_score'], 3, reason: 'best stars are kept');
    });

    test('a damaged save falls back to a fresh story', () async {
      final p = await profiles.getOrCreateGuest(AppLanguage.en);
      await story.load(p.id);
      await db.update('story_save', {
        'state_json': '{not json',
        'chapter_starts': 'nope',
      });
      final save = await story.load(p.id);
      expect(save.state.chapter, 1);
      expect(save.starts, isEmpty);
      expect(
        StoryState.fromJson({'chapter': 99, 'wallet': -5, 'txns': 'x'}).chapter,
        StoryState.chapterCount + 1,
      );
      expect(StoryState.fromJson({'wallet': -5}).wallet, 0);
    });
  });

  group('isolation, reset and clear', () {
    Future<(int, int)> twoProfiles() async {
      final a = await profiles.createProfile(
        nickname: 'A',
        language: AppLanguage.en,
      );
      final b = await profiles.createProfile(
        nickname: 'B',
        language: AppLanguage.en,
      );
      return (a.id, b.id);
    }

    test('profiles do not share a story', () async {
      final (a, b) = await twoProfiles();
      await finishChapterOne(a);
      expect((await story.load(a)).state.chapter, 2);
      expect((await story.load(b)).state.chapter, 1);
      expect((await progress.loadSnapshot(b)).completedMissionIds, isEmpty);
      expect((await progress.loadSnapshot(b)).badgeIds, isEmpty);
    });

    test("resetting one profile keeps the others' data", () async {
      final (a, b) = await twoProfiles();
      await finishChapterOne(a);
      await finishChapterOne(b);
      await progress.resetProfileProgress(a);

      final sa = await progress.loadSnapshot(a);
      expect(sa.missions, isEmpty);
      expect(sa.badgeIds, isEmpty);
      expect(await profiles.getProfile(a), isNotNull);
      expect((await story.load(a)).state.chapter, 1);

      expect((await progress.loadSnapshot(b)).completedMissionIds, {'C1'});
      expect((await progress.loadSnapshot(b)).badgeIds, {'budget_planner'});
      expect((await story.load(b)).state.chapter, 2);
    });

    test('deleting a profile removes only its data', () async {
      final (a, b) = await twoProfiles();
      await finishChapterOne(a);
      await finishChapterOne(b);
      await profiles.deleteProfile(a);
      expect(await db.query('story_save'), hasLength(1));
      expect((await progress.loadSnapshot(b)).completedMissionIds, {'C1'});
    });

    test('clear all data empties every table', () async {
      final p = await profiles.getOrCreateGuest(AppLanguage.te);
      await profiles.setActiveProfile(p.id);
      await profiles.acceptNotice();
      await finishChapterOne(p.id);
      await profiles.clearAllData();
      for (final table in [
        'profile',
        'app_state',
        'story_save',
        'mission_progress',
        'badge_award',
      ]) {
        expect(await db.query(table), isEmpty, reason: table);
      }
      expect((await profiles.loadAppState()).onboarded, isFalse);
    });
  });

  test('the story survives closing and reopening the database file', () async {
    final dir = await Directory.systemTemp.createTemp('gullak_restart');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/gullak.db';

    var fileDb = await openTestDatabase(path: path);
    final guest = await ProfileRepository(fileDb)
        .getOrCreateGuest(AppLanguage.en);
    final repo = StoryRepository(fileDb);
    final save = await repo.load(guest.id);
    await repo.completeChapter(
      profileId: guest.id,
      chapter: 1,
      stars: 3,
      revision: save.revision,
      next: StoryRules.finishChapter(save.state),
      badgeEvaluator: badgeRule,
    );
    await fileDb.close();

    fileDb = await openTestDatabase(path: path);
    final reloaded = await StoryRepository(fileDb).load(guest.id);
    expect(reloaded.state.chapter, 2);
    expect(reloaded.state.jar, 1100);
    final snapshot = await ProgressRepository(fileDb).loadSnapshot(guest.id);
    expect(snapshot.mission('C1').isCompleted, isTrue);
    expect(snapshot.badgeIds, {'budget_planner'});
    await fileDb.close();
  });
}
