import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/app/bootstrap.dart';
import 'package:gullak/data/database/app_database.dart';
import 'package:gullak/features/ngo/data/ngo_api.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// On a device/emulator with the real plugins (sqflite, secure storage,
/// HTTP) and the real backend: enrol with NGO-HYD-001 through the UI, finish
/// chapter 1, and check that the Green Futures dashboard API shows it.
///
/// Needs the backend running on the computer (`cd backend && python -m app`)
/// and the emulator (10.0.2.2) or `adb reverse tcp:8787 tcp:8787` with
/// `--dart-define=GULLAK_API_URL=http://localhost:8787` for a phone.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int ms = 3000]) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await settle(tester, 600);
    await tester.tap(finder);
    await settle(tester);
  }

  final api = Uri.parse(gullakApiUrl);

  Future<Map<String, dynamic>> dashboard(String path) async {
    final login = await http.post(
      api.replace(path: '/api/v1/dashboard/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'green.coordinator',
        'password': 'green-demo-2026',
      }),
    );
    final token = (jsonDecode(login.body) as Map)['session_token'];
    final r = await http.get(
      api.replace(path: '/api/v1/dashboard$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  testWidgets('enrol through the UI, play chapter 1, appear on the dashboard', (
    tester,
  ) async {
    final health = await http.get(api.replace(path: '/api/v1/health'));
    expect(health.statusCode, 200, reason: 'start the backend first');

    final path = p.join(await getDatabasesPath(), AppDatabase.fileName);
    await deleteDatabase(path);
    await tester.pumpWidget(const GullakBootstrap());
    await settle(tester);

    await tap(tester, 'lang_en');
    await tap(tester, 'notice_accept');
    await tap(tester, 'profile_guest');
    await tap(tester, 'level_easy');
    // Use the test text input: on a device the real keyboard would
    // otherwise send back its own (empty) editing state.
    tester.testTextInput.register();
    await tester.enterText(
      find.byKey(const ValueKey('ngo_code_field')),
      'NGO-HYD-001',
    );
    await tap(tester, 'ngo_check');
    await settle(tester, 2000);
    expect(find.text('Green Futures Foundation'), findsOneWidget);
    await tap(tester, 'ngo_consent');
    await tap(tester, 'ngo_join');
    await settle(tester, 3000);
    expect(find.byKey(const ValueKey('sync_chip_synced')), findsOneWidget);

    final db = await openDatabase(path, singleInstance: true);
    final studentId =
        (await db.query('ngo_enrolment')).single['student_id']! as String;
    var row = await dashboard('/students/$studentId');
    expect(row['student_id'], studentId);

    await tap(tester, 'play_next');
    for (var i = 0; i < 6; i++) {
      await tap(tester, 'story_next');
    }
    for (final item in ['bus', 'lunch', 'recharge']) {
      await tap(tester, 'item_$item');
    }
    await tap(tester, 'budget_submit');
    await tap(tester, 'story_next');
    await tap(tester, 'story_next');
    await tap(tester, 'opt_own');
    await tap(tester, 'pick_confirm');
    await tap(tester, 'story_next');
    for (final bin in ['left', 'left', 'left', 'left']) {
      await tap(tester, 'bin_$bin');
    }
    await tap(tester, 'activity_done');
    await tap(tester, 'story_next');
    await tap(tester, 'finish_chapter');
    // Finishing a chapter triggers a sync.
    await settle(tester, 4000);

    expect(await db.query('sync_outbox'), isEmpty);
    row = await dashboard('/students/$studentId');
    expect(row['chapters'][0]['state'], 'completed');
    expect(row['badges'], contains('budget_planner'));
  });
}
