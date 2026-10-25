import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/features/ngo/application/ngo_sync.dart';
import 'package:gullak/features/ngo/domain/enrolment.dart';

import 'ngo_harness.dart';

void main() {
  late NgoHarness h;
  setUp(() async => h = await NgoHarness.open());
  tearDown(() => h.db.close());

  test('valid code joins, uploads and clears the outbox', () async {
    final p = await h.newProfile('Asha');
    await h.finishChapterOne(p); // progress from before joining
    expect(await h.sync.join(p, ' ngo-hyd-001 '), JoinOutcome.joined);
    final e = (await h.enrolments.get(p))!;
    expect(e.status, EnrolmentStatus.active);
    expect(e.studentId, startsWith('STU-'));
    expect(e.ngoName, 'Green Futures Foundation');
    expect(await h.tokens.read(e.registrationKey), isNotNull);
    // Token is never stored in SQLite.
    final row = (await h.db.query('ngo_enrolment')).single;
    expect(
      row.values.whereType<String>().any((v) => v.startsWith('gst_')),
      isFalse,
    );
    final report = h.server.latest(e.studentId!)!;
    expect(report['student_id'], e.studentId);
    expect((report['chapters']! as List).single, containsPair('id', 'C1'));
    expect(await h.outbox.pending(p), isNull);
    expect(e.lastSyncedAt, isNotNull);
  });

  test(
    'invalid and revoked codes are refused and nothing is registered',
    () async {
      final p = await h.newProfile('Asha');
      expect(await h.sync.join(p, 'NGO-XXX-999'), JoinOutcome.invalidCode);
      expect((await h.enrolments.get(p))!.status, EnrolmentStatus.rejected);
      expect(await h.sync.join(p, 'NGO-HYD-000'), JoinOutcome.revokedCode);
      expect(h.server.byKey, isEmpty);
      // A new valid code fixes it.
      expect(await h.sync.join(p, 'NGO-HYD-001'), JoinOutcome.joined);
    },
  );

  test('offline join is saved and registers on the next sync', () async {
    final p = await h.newProfile('Asha');
    h.server.offline = true;
    expect(await h.sync.join(p, 'NGO-HYD-001'), JoinOutcome.savedOffline);
    await h.finishChapterOne(p); // offline play still queues progress
    var e = (await h.enrolments.get(p))!;
    expect(e.status, EnrolmentStatus.pending);
    expect(await h.outbox.pending(p), isNotNull);
    h.server.offline = false;
    await h.sync.sync();
    e = (await h.enrolments.get(p))!;
    expect(e.status, EnrolmentStatus.active);
    expect(h.server.latest(e.studentId!), isNotNull);
    expect(await h.outbox.pending(p), isNull);
  });

  test(
    'a lost registration reply is retried without a second student',
    () async {
      final p = await h.newProfile('Asha');
      // Server registers, but the reply never arrives.
      await h.enrolments.start(
        p,
        code: 'NGO-HYD-001',
        registrationKey: 'retry-aaaaaaaaaaaaaaaaaaaa',
      );
      await h.server.api().register(
        code: 'NGO-HYD-001',
        registrationKey: 'retry-aaaaaaaaaaaaaaaaaaaa',
        appVersion: '1',
      );
      await h.sync.sync();
      expect(h.server.byKey, hasLength(1));
      expect(
        (await h.enrolments.get(p))!.studentId,
        h.server.byKey.values.single,
      );
    },
  );

  test('offline progress stays local and uploads later', () async {
    final p = await h.newProfile('Asha');
    await h.sync.join(p, 'NGO-HYD-001');
    final id = (await h.enrolments.get(p))!.studentId!;
    h.server.offline = true;
    await h.finishChapterOne(p);
    await h.sync.sync();
    expect((await h.enrolments.get(p))!.lastError, 'offline');
    expect(await h.outbox.pending(p), isNotNull);
    expect((await h.story.load(p)).state.chapter, 2, reason: 'game unaffected');
    expect(h.server.latest(id)!['chapters'], isEmpty);
    h.server.offline = false;
    await h.sync.sync();
    expect((h.server.latest(id)!['chapters']! as List), hasLength(1));
    expect(await h.outbox.pending(p), isNull);
  });

  test('server failure backs off, then a retry succeeds', () async {
    final p = await h.newProfile('Asha');
    await h.sync.join(p, 'NGO-HYD-001');
    final id = (await h.enrolments.get(p))!.studentId!;
    await h.finishChapterOne(p);
    h.server.failNext = 1;
    await h.sync.sync();
    expect((await h.outbox.pending(p))!.attempts, 1);
    final posts = h.server.progressPosts;
    await h.sync.sync(); // within backoff: not sent
    expect(h.server.progressPosts, posts);
    h.now = h.now.add(const Duration(minutes: 1));
    await h.sync.sync();
    expect(await h.outbox.pending(p), isNull);
    expect((h.server.latest(id)!['chapters']! as List), hasLength(1));
  });

  test('"Sync now" ignores the backoff', () async {
    final p = await h.newProfile('Asha');
    await h.sync.join(p, 'NGO-HYD-001');
    await h.finishChapterOne(p);
    h.server.failNext = 1;
    await h.sync.sync();
    await h.sync.sync(force: true);
    expect(await h.outbox.pending(p), isNull);
  });

  test('concurrent sync calls send each report once', () async {
    final p = await h.newProfile('Asha');
    await h.sync.join(p, 'NGO-HYD-001');
    await h.finishChapterOne(p);
    final before = h.server.progressPosts;
    await Future.wait([h.sync.sync(), h.sync.sync(), h.sync.sync(force: true)]);
    expect(h.server.progressPosts - before, 1);
  });

  test('stale revision: the server has newer data, report is renumbered', () async {
    final p = await h.newProfile('Asha');
    await h.sync.join(p, 'NGO-HYD-001');
    final e = (await h.enrolments.get(p))!;
    // Server already holds revision 50 for this student (e.g. restored phone).
    h.server.reports[e.studentId!]![50] = {
      'student_id': e.studentId,
      'revision': 50,
    };
    await h.finishChapterOne(p);
    await h.sync.sync();
    expect(await h.outbox.pending(p), isNull);
    expect(
      h.server.reports[e.studentId!]!.keys.reduce((a, b) => a > b ? a : b),
      51,
    );
  });

  test('a revoked token stops syncing and asks for a new code', () async {
    final p = await h.newProfile('Asha');
    await h.sync.join(p, 'NGO-HYD-001');
    final e = (await h.enrolments.get(p))!;
    h.server.revokeStudent(e.studentId!);
    await h.finishChapterOne(p);
    await h.sync.sync();
    final after = (await h.enrolments.get(p))!;
    expect(after.status, EnrolmentStatus.revoked);
    expect(after.needsAction, isTrue);
    expect(await h.tokens.read(e.registrationKey), isNull);
    expect((await h.story.load(p)).state.chapter, 2, reason: 'progress kept');
  });

  test(
    'two profiles on one phone sync to different NGOs independently',
    () async {
      final a = await h.newProfile('Asha');
      final b = await h.newProfile('Ravi');
      await h.sync.join(a, 'NGO-HYD-001');
      await h.sync.join(b, 'NGO-WGL-001');
      await h.finishChapterOne(a);
      await h.sync.sync();
      final ea = (await h.enrolments.get(a))!;
      final eb = (await h.enrolments.get(b))!;
      expect(ea.studentId, isNot(eb.studentId));
      expect(h.server.ngoOf[ea.studentId], 'Green Futures Foundation');
      expect(h.server.ngoOf[eb.studentId], 'Udaan Learning Trust');
      expect(
        (h.server.latest(ea.studentId!)!['chapters']! as List),
        hasLength(1),
      );
      expect(h.server.latest(eb.studentId!)!['chapters'], isEmpty);
      expect(ea.registrationKey, isNot(eb.registrationKey));
      // Ravi's link failing does not affect Asha.
      h.server.revokeStudent(eb.studentId!);
      await h.finishChapterOne(b);
      await h.step(a);
      await h.sync.sync();
      expect((await h.enrolments.get(b))!.status, EnrolmentStatus.revoked);
      expect((await h.enrolments.get(a))!.status, EnrolmentStatus.active);
    },
  );

  test('unlink deletes the server copy and keeps local progress', () async {
    final p = await h.newProfile('Asha');
    await h.sync.join(p, 'NGO-HYD-001');
    await h.finishChapterOne(p);
    await h.sync.sync();
    final id = (await h.enrolments.get(p))!.studentId!;
    h.server.offline = true;
    await h.sync.unlink(p);
    expect((await h.enrolments.get(p))!.status, EnrolmentStatus.unlinking);
    await h.step(p);
    expect(await h.outbox.pending(p), isNull, reason: 'no new uploads');
    h.server.offline = false;
    await h.sync.sync();
    expect(await h.enrolments.get(p), isNull);
    expect(h.server.reports[id], isNull);
    expect((await h.story.load(p)).state.chapter, 2);
    expect(h.tokens.tokens, isEmpty);
  });

  test('progress survives an app restart and uploads afterwards', () async {
    final p = await h.newProfile('Asha');
    await h.sync.join(p, 'NGO-HYD-001');
    h.server.offline = true;
    await h.finishChapterOne(p);
    await h.sync.sync();
    // "Restart": a brand-new sync service over the same storage.
    h.server.offline = false;
    final restarted = h.syncWith(h.server.api());
    await restarted.sync();
    final id = (await h.enrolments.get(p))!.studentId!;
    expect((h.server.latest(id)!['chapters']! as List), hasLength(1));
  });
}
