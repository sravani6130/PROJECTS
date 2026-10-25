@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/features/ngo/application/ngo_sync.dart';
import 'package:gullak/features/ngo/data/ngo_api.dart';
import 'package:gullak/features/ngo/data/outbox_repository.dart';
import 'package:http/http.dart' as http;

import '../ngo/ngo_harness.dart';

/// The app's real sync code against the real Python backend (started here
/// on a free port with a temporary database). Skipped when the backend's
/// virtualenv is missing: `cd backend && python3 -m venv .venv &&
/// .venv/bin/pip install -r requirements-dev.txt`.
void main() {
  final python = File('backend/.venv/bin/python');
  final skip = python.existsSync() ? null : 'backend/.venv not set up';
  late Process server;
  late Uri base;
  late Directory dir;

  setUpAll(() async {
    if (skip != null) return;
    dir = await Directory.systemTemp.createTemp('gullak_e2e');
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    base = Uri.parse('http://127.0.0.1:$port');
    final env = Map.of(Platform.environment)..remove('PYTHONPATH');
    server = await Process.start(
      python.absolute.path,
      ['-m', 'app'],
      workingDirectory: 'backend',
      environment: {
        ...env,
        'GULLAK_ENV': 'test',
        'GULLAK_DB_PATH': '${dir.path}/e2e.db',
        'GULLAK_PORT': '$port',
        'GULLAK_SEED_DEMO': 'true',
        'GULLAK_ENROL_RATE_PER_MINUTE': '0',
      },
      includeParentEnvironment: false,
    );
    server.stdout.drain<void>();
    server.stderr.drain<void>();
    for (var i = 0; i < 100; i++) {
      try {
        final r = await http.get(base.replace(path: '/api/v1/health'));
        if (r.statusCode == 200) return;
      } on Object {
        // not up yet
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('backend did not start');
  });

  tearDownAll(() async {
    if (skip != null) return;
    server.kill();
    await server.exitCode;
    await dir.delete(recursive: true);
  });

  Future<Map<String, dynamic>> dashboard(
    String user,
    String pass,
    String path,
  ) async {
    final login = await http.post(
      base.replace(path: '/api/v1/dashboard/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': user, 'password': pass}),
    );
    final token = (jsonDecode(login.body) as Map)['session_token'];
    final r = await http.get(
      base.replace(path: '/api/v1/dashboard$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  test(
    'students appear on the right dashboard after enrolling and syncing',
    () async {
      final h = await NgoHarness.open();
      addTearDown(h.db.close);
      final api = NgoApi(client: http.Client(), baseUrl: base);
      final sync = h.syncWith(api);
      // An API pointing at a closed port behaves like a phone with no network.
      final offlineSync = h.syncWith(
        NgoApi(client: http.Client(), baseUrl: Uri.parse('http://127.0.0.1:9')),
      );

      final asha = await h.newProfile('Asha');
      final ravi = await h.newProfile('Ravi');
      expect(await sync.join(asha, 'NGO-HYD-001'), JoinOutcome.joined);
      expect(await sync.join(ravi, 'NGO-VJA-001'), JoinOutcome.joined);
      final a = (await h.enrolments.get(asha))!;
      final r = (await h.enrolments.get(ravi))!;

      var green = await dashboard(
        'green.coordinator',
        'green-demo-2026',
        '/students',
      );
      var yfc = await dashboard(
        'yfc.coordinator',
        'yfc-demo-2026',
        '/students',
      );
      expect(
        [for (final s in green['students']) s['student_id']],
        [a.studentId],
      );
      expect([for (final s in yfc['students']) s['student_id']], [r.studentId]);
      final udaan = await dashboard(
        'udaan.coordinator',
        'udaan-demo-2026',
        '/overview',
      );
      expect(udaan['totals']['enrolled'], 0);

      // Offline play: saved and queued, nothing reaches the server.
      await h.finishChapterOne(asha);
      await offlineSync.sync();
      expect(await h.outbox.pending(asha), isNotNull);
      green = await dashboard(
        'green.coordinator',
        'green-demo-2026',
        '/students',
      );
      expect(green['students'][0]['chapters_completed'], 0);

      // Back online.
      await sync.sync();
      expect(await h.outbox.pending(asha), isNull);
      green = await dashboard(
        'green.coordinator',
        'green-demo-2026',
        '/overview',
      );
      expect(green['totals']['enrolled'], 1);
      expect(green['totals']['story_completed'], 0);
      expect(green['chapters'][0]['completed'], 1);

      // Retrying the same upload creates nothing new.
      final token = (await h.tokens.read(a.registrationKey))!;
      final ack = (await h.enrolments.get(asha))!;
      final again = await api.uploadProgress(token, {
        ...(jsonDecode(ack.ackedContent!) as Map).cast<String, Object?>(),
        'schema_version': 1,
        'student_id': a.studentId,
        'revision': ack.ackedRevision,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      });
      expect(again.status, 'duplicate');
      final detail = await dashboard(
        'green.coordinator',
        'green-demo-2026',
        '/students/${a.studentId}',
      );
      expect(detail['chapters'][0]['state'], 'completed');
      final revisions = [for (final x in detail['history']) x['revision']];
      expect(revisions.toSet().length, revisions.length);
      green = await dashboard(
        'green.coordinator',
        'green-demo-2026',
        '/overview',
      );
      expect(green['totals']['enrolled'], 1);
      expect(green['chapters'][0]['completed'], 1);

      // Cross-tenant: Green Futures cannot open Ravi.
      final cross = await dashboard(
        'green.coordinator',
        'green-demo-2026',
        '/students/${r.studentId}',
      );
      expect(cross['error']['code'], 'student_not_found');

      // Unlink removes the student from the dashboard; the game is untouched.
      await sync.unlink(asha);
      green = await dashboard(
        'green.coordinator',
        'green-demo-2026',
        '/overview',
      );
      expect(green['totals']['enrolled'], 0);
      expect((await h.story.load(asha)).state.chapter, 2);
      expect(OutboxRepository.backoff(1), isNotNull);
    },
    skip: skip,
  );
}
