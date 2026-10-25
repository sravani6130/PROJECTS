import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/data/database/migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_support.dart';

void main() {
  late Database db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  Future<int> insertProfile({String? nickname, int guest = 0}) =>
      db.insert('profile', {
        'nickname': nickname,
        'is_guest': guest,
        'created_at': 't',
        'last_active_at': 't',
      });

  Future<void> insertAttempt(String id, int profileId, {bool open = true}) =>
      db.insert('attempt', {
        'attempt_id': id,
        'profile_id': profileId,
        'mission_id': 'M01',
        'start_balance': 500,
        'max_score': 3,
        'started_at': 't',
        if (!open) ...{'finished_at': 't', 'result': 'completed'},
      });

  test(
    'creates every table at the latest schema version with foreign keys on',
    () async {
      expect(await db.getVersion(), appMigrations.length);
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      expect(tables.map((r) => r['name']), [
        'app_state',
        'assessment_result',
        'attempt',
        'attempt_decision',
        'badge_award',
        'daily_checkin',
        'inbox',
        'mission_progress',
        'ngo_enrolment',
        'profile',
        'story_save',
        'study_progress',
        'sync_outbox',
      ]);
      final fk = await db.rawQuery('PRAGMA foreign_keys');
      expect(fk.single.values.single, 1);
    },
  );

  group('constraints', () {
    test('profile grade and guest/nickname rules', () async {
      await expectLater(
        db.insert('profile', {
          'nickname': 'Asha',
          'grade': 13,
          'created_at': 't',
          'last_active_at': 't',
        }),
        throwsA(isA<DatabaseException>()),
      );
      // A named profile needs a nickname; a guest must not have one.
      await expectLater(insertProfile(), throwsA(isA<DatabaseException>()));
      await expectLater(
        insertProfile(nickname: 'x', guest: 1),
        throwsA(isA<DatabaseException>()),
      );
    });

    test(
      'only one guest profile, and nicknames are unique ignoring case',
      () async {
        await insertProfile(guest: 1);
        await expectLater(
          insertProfile(guest: 1),
          throwsA(isA<DatabaseException>()),
        );
        await insertProfile(nickname: 'Ravi');
        await expectLater(
          insertProfile(nickname: 'RAVI'),
          throwsA(isA<DatabaseException>()),
        );
      },
    );

    test('nickname length is capped at 20', () async {
      await expectLater(
        insertProfile(nickname: 'x' * 21),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('attempt needs an existing profile', () async {
      await expectLater(
        insertAttempt('a', 999),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('at most one open attempt per profile and mission', () async {
      final p = await insertProfile(nickname: 'A');
      await insertAttempt('a1', p);
      await expectLater(
        insertAttempt('a2', p),
        throwsA(isA<DatabaseException>()),
      );
      await insertAttempt('a3', p, open: false); // finished ones are fine
    });

    test('finished_at and result must be set together', () async {
      final p = await insertProfile(nickname: 'A');
      await expectLater(
        db.insert('attempt', {
          'attempt_id': 'x',
          'profile_id': p,
          'mission_id': 'M01',
          'start_balance': 0,
          'max_score': 3,
          'started_at': 't',
          'finished_at': 't',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test(
      'decisions: no duplicates, no negative balance, no finished attempt',
      () async {
        final p = await insertProfile(nickname: 'A');
        await insertAttempt('open', p);
        await insertAttempt('done', p, open: false);
        Map<String, Object?> row(String attempt, int no, {int balance = 0}) => {
          'attempt_id': attempt,
          'decision_no': no,
          'step_index': 0,
          'choice_ids': 'x',
          'verdict': 'best',
          'balance_after': balance,
          'decided_at': 't',
        };
        await db.insert('attempt_decision', row('open', 1));
        await expectLater(
          db.insert('attempt_decision', row('open', 1)),
          throwsA(isA<DatabaseException>()),
        );
        await expectLater(
          db.insert('attempt_decision', row('open', 2, balance: -5)),
          throwsA(isA<DatabaseException>()),
        );
        await expectLater(
          db.insert('attempt_decision', row('done', 1)),
          throwsA(isA<DatabaseException>()),
        );
      },
    );

    test('quiz scores cannot exceed the maximum', () async {
      final p = await insertProfile(nickname: 'A');
      await expectLater(
        db.insert('assessment_result', {
          'profile_id': p,
          'kind': 'topic_quiz',
          'topic_id': 'T01',
          'score': 4,
          'max_score': 3,
          'taken_at': 't',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('deleting a profile cascades to its rows', () async {
      final p = await insertProfile(nickname: 'A');
      await insertAttempt('a', p);
      await db.insert('badge_award', {
        'profile_id': p,
        'badge_id': 'scam_spotter',
        'awarded_at': 't',
      });
      await db.delete('profile', where: 'profile_id = ?', whereArgs: [p]);
      expect(await db.query('attempt'), isEmpty);
      expect(await db.query('badge_award'), isEmpty);
    });

    test('one story save per profile, removed with the profile', () async {
      final p = await insertProfile(nickname: 'A');
      Future<int> save() => db.insert('story_save', {
        'profile_id': p,
        'state_json': '{}',
        'updated_at': 't',
      });
      await save();
      await expectLater(save(), throwsA(isA<DatabaseException>()));
      await expectLater(
        db.insert('story_save', {
          'profile_id': 999,
          'state_json': '{}',
          'updated_at': 't',
        }),
        throwsA(isA<DatabaseException>()),
      );
      await db.delete('profile', where: 'profile_id = ?', whereArgs: [p]);
      expect(await db.query('story_save'), isEmpty);
    });
  });

  group('migrations', () {
    test(
      'a version 1 database gains the story table and keeps its rows',
      () async {
        final dir = await Directory.systemTemp.createTemp('gullak_migration');
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}/gullak.db';

        final v1 = await openTestDatabase(
          path: path,
          migrations: [appMigrations.first],
        );
        final p = await v1.insert('profile', {
          'nickname': 'Old',
          'created_at': 't',
          'last_active_at': 't',
        });
        await v1.insert('badge_award', {
          'profile_id': p,
          'badge_id': 'budget_planner',
          'awarded_at': 't',
        });
        await v1.close();

        final latest = await openTestDatabase(path: path);
        expect(await latest.getVersion(), appMigrations.length);
        expect(await latest.query('story_save'), isEmpty);
        expect((await latest.query('profile')).single['nickname'], 'Old');
        expect(await latest.query('badge_award'), hasLength(1));
        await latest.close();
      },
    );

    test('upgrading preserves existing records', () async {
      final dir = await Directory.systemTemp.createTemp('gullak_migration');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/gullak.db';

      final v1 = await openTestDatabase(path: path);
      await v1.insert('profile', {
        'nickname': 'Meera',
        'created_at': 't',
        'last_active_at': 't',
      });
      await v1.close();

      // A hypothetical future migration that adds a column.
      final v2 = await openTestDatabase(
        path: path,
        migrations: [
          ...appMigrations,
          Migration(appMigrations.length + 1, 'test: add font scale', const [
            'ALTER TABLE profile ADD COLUMN font_scale REAL NOT NULL DEFAULT 1.0',
          ]),
        ],
      );
      expect(await v2.getVersion(), appMigrations.length + 1);
      final rows = await v2.query('profile');
      expect(rows.single['nickname'], 'Meera');
      expect(rows.single['font_scale'], 1.0);
      await v2.close();
    });

    test('a failing migration rolls back and keeps the old version', () async {
      final dir = await Directory.systemTemp.createTemp('gullak_migration');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/gullak.db';
      final v1 = await openTestDatabase(path: path);
      await v1.insert('profile', {
        'nickname': 'Kavya',
        'created_at': 't',
        'last_active_at': 't',
      });
      await v1.close();

      await expectLater(
        openTestDatabase(
          path: path,
          migrations: [
            ...appMigrations,
            Migration(appMigrations.length + 1, 'broken', const [
              'ALTER TABLE profile ADD COLUMN ok INTEGER',
              'THIS IS NOT SQL',
            ]),
          ],
        ),
        throwsA(isA<DatabaseException>()),
      );

      final reopened = await openTestDatabase(path: path);
      expect(await reopened.getVersion(), appMigrations.length);
      final columns = await reopened.rawQuery('PRAGMA table_info(profile)');
      expect(columns.map((c) => c['name']), isNot(contains('ok')));
      expect((await reopened.query('profile')).single['nickname'], 'Kavya');
      await reopened.close();
    });

    test('migration versions must be contiguous', () {
      expect(
        () => checkMigrations(const [Migration(2, 'x', [])]),
        throwsStateError,
      );
    });
  });
}
