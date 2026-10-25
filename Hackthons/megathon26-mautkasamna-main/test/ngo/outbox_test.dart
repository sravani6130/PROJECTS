import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/data/database/migrations.dart';
import 'package:gullak/features/ngo/data/outbox_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_support.dart';
import 'ngo_harness.dart';

void main() {
  late NgoHarness h;
  setUp(() async => h = await NgoHarness.open());
  tearDown(() => h.db.close());

  Future<void> link(int profileId) => h.enrolments.start(
    profileId,
    code: 'NGO-HYD-001',
    registrationKey: 'key-$profileId-aaaaaaaaaaaaaaaaaaaa',
  );

  test('nothing is queued for a profile that is not linked', () async {
    final p = await h.newProfile('Asha');
    await h.finishChapterOne(p);
    expect(await h.outbox.pending(p), isNull);
    expect(await h.db.query('sync_outbox'), isEmpty);
  });

  test('a progress change queues a report in the same transaction', () async {
    final p = await h.newProfile('Asha');
    await link(p);
    await h.finishChapterOne(p);
    final item = (await h.outbox.pending(p))!;
    expect(item.revision, 1);
    final content = jsonDecode(item.content) as Map;
    expect(content['chapters'], [
      {
        'id': 'C1',
        'completed': true,
        'best_stars': 3,
        'plays': 1,
        'first_completed_at': '2026-10-11T09:00:00.000Z',
      },
    ]);
    expect(content['badges'], ['budget_planner']);
    expect((content['story'] as Map)['current_chapter'], 2);
  });

  test('a failing progress write queues nothing (rolled back)', () async {
    final p = await h.newProfile('Asha');
    await link(p);
    final save = await h.story.load(p);
    await h.story.saveStep(p, save.state.copyWith(beat: 1), save.revision);
    final queued = (await h.outbox.pending(p))!.revision;
    // A stale write is rejected: neither the save nor the outbox changes.
    await expectLater(
      h.story.saveStep(p, save.state.copyWith(beat: 2), save.revision),
      throwsA(anything),
    );
    expect((await h.outbox.pending(p))!.revision, queued);
  });

  test(
    'newer snapshots replace older ones; unchanged ones are skipped',
    () async {
      final p = await h.newProfile('Asha');
      await link(p);
      await h.step(p);
      final first = (await h.outbox.pending(p))!;
      // Same hour, same summary: nothing new to send.
      await h.step(p);
      expect((await h.outbox.pending(p))!.revision, first.revision);
      await h.finishChapterOne(p);
      final rows = await h.db.query('sync_outbox');
      expect(rows, hasLength(1), reason: 'coalesced into one row');
      expect(rows.single['revision'], first.revision + 1);
    },
  );

  test('acknowledged content is not queued again', () async {
    final p = await h.newProfile('Asha');
    await link(p);
    await h.finishChapterOne(p);
    final item = (await h.outbox.pending(p))!;
    await h.outbox.acknowledge(p, item.revision, item.content);
    expect(await h.outbox.pending(p), isNull);
    expect(await h.outbox.refresh(p), isFalse);
    expect(await h.outbox.pending(p), isNull);
  });

  test(
    'an acknowledgement for an older revision keeps the newer one',
    () async {
      final p = await h.newProfile('Asha');
      await link(p);
      await h.step(p);
      final sent = (await h.outbox.pending(p))!;
      await h.finishChapterOne(p); // progress while the upload is in flight
      await h.outbox.acknowledge(p, sent.revision, sent.content);
      final left = (await h.outbox.pending(p))!;
      expect(left.revision, sent.revision + 1);
      expect((await h.enrolments.get(p))!.ackedRevision, sent.revision);
    },
  );

  test('resetting progress queues the reset for the NGO', () async {
    final p = await h.newProfile('Asha');
    await link(p);
    await h.finishChapterOne(p);
    final item = (await h.outbox.pending(p))!;
    await h.outbox.acknowledge(p, item.revision, item.content);
    await h.progress.resetProfileProgress(p);
    final reset = jsonDecode((await h.outbox.pending(p))!.content) as Map;
    expect(reset['chapters'], isEmpty);
    // The NGO link survives a progress reset.
    expect(await h.enrolments.get(p), isNotNull);
  });

  test('server errors back off exponentially, offline does not', () async {
    final p = await h.newProfile('Asha');
    await link(p);
    await h.finishChapterOne(p);
    await h.outbox.recordFailure(p, serverError: false);
    expect((await h.outbox.pending(p))!.dueAt(h.now), isTrue);
    await h.outbox.recordFailure(p, serverError: true);
    var item = (await h.outbox.pending(p))!;
    expect(item.attempts, 2);
    expect(item.dueAt(h.now), isFalse);
    expect(item.dueAt(h.now.add(const Duration(seconds: 61))), isTrue);
    expect(OutboxRepository.backoff(1), const Duration(seconds: 30));
    expect(OutboxRepository.backoff(3), const Duration(minutes: 2));
    expect(OutboxRepository.backoff(30), const Duration(hours: 1));
    item = (await h.outbox.pending(p))!;
    await h.outbox.acknowledge(p, item.revision, item.content);
    expect(await h.outbox.pending(p), isNull);
  });

  test('the outbox survives closing and reopening the app', () async {
    final dir = await Directory.systemTemp.createTemp('gullak_outbox');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/gullak.db';
    final first = await NgoHarness.open(path: path);
    final p = await first.newProfile('Asha');
    await first.enrolments.start(
      p,
      code: 'NGO-HYD-001',
      registrationKey: 'persist-aaaaaaaaaaaaaaaaaaaa',
    );
    await first.finishChapterOne(p);
    final before = (await first.outbox.pending(p))!;
    await first.db.close();

    final second = await NgoHarness.open(path: path);
    addTearDown(second.db.close);
    final after = (await second.outbox.pending(p))!;
    expect(after.revision, before.revision);
    expect(after.content, before.content);
    expect((await second.enrolments.get(p))!.code, 'NGO-HYD-001');
  });

  test('upgrading a version 4 database keeps saved progress', () async {
    final dir = await Directory.systemTemp.createTemp('gullak_v4');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/gullak.db';
    final v4 = await openTestDatabase(
      path: path,
      migrations: appMigrations.sublist(0, 4),
    );
    final p = await v4.insert('profile', {
      'nickname': 'Old',
      'created_at': 't',
      'last_active_at': 't',
    });
    await v4.insert('story_save', {
      'profile_id': p,
      'state_json': '{"chapter":3,"bank":500,"done":{"1":3,"2":2}}',
      'revision': 9,
      'updated_at': 't',
    });
    for (final (id, stars) in [('C1', 3), ('C2', 2)]) {
      await v4.insert('mission_progress', {
        'profile_id': p,
        'mission_id': id,
        'status': 'completed',
        'best_score': stars,
        'max_score': 3,
        'attempt_count': 1,
        'completion_count': 1,
        'first_completed_at': 't',
        'last_played_at': 't',
      });
    }
    await v4.insert('badge_award', {
      'profile_id': p,
      'badge_id': 'budget_planner',
      'awarded_at': 't',
    });
    await v4.close();

    final h5 = await NgoHarness.open(path: path);
    addTearDown(h5.db.close);
    expect(await h5.db.getVersion(), appMigrations.length);
    final save = await h5.story.load(p);
    expect(save.state.chapter, 3);
    expect(save.state.bank, 500);
    expect(save.revision, 9);
    expect(await h5.db.query('mission_progress'), hasLength(2));
    expect(await h5.db.query('badge_award'), hasLength(1));
    final profile = await h5.profiles.getProfile(p);
    expect(profile!.ngoPromptDone, isFalse); // asked once after upgrade
    // Linking later reports the progress that already existed.
    await h5.enrolments.start(
      p,
      code: 'NGO-HYD-001',
      registrationKey: 'up-aaaaaaaaaaaaaaaaaaaaaa',
    );
    await h5.outbox.refresh(p);
    final content = jsonDecode((await h5.outbox.pending(p))!.content) as Map;
    expect((content['chapters'] as List), hasLength(2));
    expect((content['story'] as Map)['current_chapter'], 3);
  });
}
