import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/app/app.dart';
import 'package:gullak/app/bootstrap.dart';
import 'package:gullak/core/audio/narrator.dart';
import 'package:gullak/core/localization/app_language.dart';
import 'package:gullak/core/notifications/reminders.dart';
import 'package:gullak/app/providers.dart';
import 'package:gullak/data/database/app_database.dart';
import 'package:gullak/data/database/migrations.dart';
import 'package:gullak/features/content/domain/content_models.dart';
import 'package:gullak/features/content/data/content_repository.dart';
import 'package:gullak/features/ngo/application/ngo_providers.dart';
import 'package:gullak/features/ngo/data/ngo_api.dart';
import 'package:gullak/features/ngo/data/token_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Real SQLite (via FFI) in memory. The no-isolate factory keeps database
/// futures inside the test zone so widget tests can pump normally.
Future<Database> openTestDatabase({
  List<Migration> migrations = appMigrations,
  String path = inMemoryDatabasePath,
}) {
  sqfliteFfiInit();
  return AppDatabase.open(
    factory: databaseFactoryFfiNoIsolate,
    path: path,
    migrations: migrations,
  );
}

/// The bundled content exactly as the app ships it.
Future<ContentCatalog> loadTestContent() =>
    ContentRepository(rootBundle).loadCatalog();

Future<AppServices> loadTestServices({Database? database}) async {
  final db = database ?? await openTestDatabase();
  return AppServices.load(bundle: rootBundle, openDatabase: () async => db);
}

bool _fontsLoaded = false;

/// Loads the bundled game font so layouts are measured with real glyphs
/// (Telugu included) instead of the square test font.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final loader = FontLoader('Baloo')
    ..addFont(rootBundle.load('assets/fonts/BalooTammudu2.ttf'));
  await loader.load();
}

/// Stands in for the phone's speech engine and records what was said.
class RecordingNarrator extends Narrator {
  final said = <String>[];
  final _speaking = ValueNotifier<String?>(null);
  bool voiceAvailable = true;

  @override
  ValueListenable<String?> get speaking => _speaking;

  @override
  Future<void> speak(String text, AppLanguage language, ReadAloud pace) async {
    said.add(text);
    _speaking.value = text;
  }

  @override
  Future<void> stop() async => _speaking.value = null;

  @override
  Future<bool> hasVoice(AppLanguage language) async => voiceAvailable;
}

/// Stands in for phone notifications and keeps the latest schedule.
class FakeReminders extends Reminders {
  List<PlannedReminder> scheduled = const [];
  bool allow = true;
  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allow;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async =>
      scheduled = reminders;

  /// Bodies of notifications shown on the phone right away.
  final shown = <String>[];

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async => shown.add(body);
}

/// An NGO API whose every request fails as if the phone were offline.
NgoApi offlineNgoApi() => NgoApi(
  client: MockClient((_) async => throw http.ClientException('offline')),
  baseUrl: Uri.parse('http://localhost:8787'),
);

/// Pumps the full app on a tall phone-sized surface.
Future<AppServices> pumpGullak(
  WidgetTester tester, {
  AppServices? services,
  Narrator? narrator,
  Reminders? reminders,

  /// NGO server stand-in; offline when null.
  NgoApi? ngoApi,
  TokenStore? tokenStore,

  /// Fixed time for check-ins and reminders; the real clock when null.
  DateTime Function()? clock,
  Size logicalSize = const Size(432, 960),
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 2.5;
  tester.view.physicalSize = logicalSize * 2.5;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  // Reduced motion: ambient loops stop and text appears at once, so
  // pumpAndSettle can settle. This is the same path users with the system
  // "remove animations" setting get.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.runAsync(loadAppFonts);
  final loaded =
      services ?? await tester.runAsync(loadTestServices) as AppServices;
  // sqflite reuses an open in-memory database by path, so close it to keep
  // tests independent. Tests that pass [services] manage their own database.
  if (services == null) addTearDown(loaded.database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...loaded.overrides,
        narratorProvider.overrideWithValue(narrator ?? RecordingNarrator()),
        remindersProvider.overrideWithValue(reminders ?? FakeReminders()),
        ngoApiProvider.overrideWithValue(ngoApi ?? offlineNgoApi()),
        tokenStoreProvider.overrideWithValue(tokenStore ?? MemoryTokenStore()),
        if (clock != null) clockProvider.overrideWithValue(clock),
      ],
      retry: (_, _) => null,
      child: const GullakApp(),
    ),
  );
  await tester.pumpAndSettle();
  return loaded;
}
