import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/audio/narrator.dart';
import '../core/localization/app_language.dart';
import '../core/localization/app_strings.dart';
import '../core/utils/ids.dart';
import '../features/content/domain/content_models.dart';
import '../features/ngo/application/ngo_providers.dart';
import '../features/profiles/application/app_session_controller.dart';
import '../features/profiles/data/profile_repository.dart';
import '../features/progress/data/progress_repository.dart';

// Startup dependencies. These are overridden in `bootstrap.dart` (and in
// tests) once the database is open and content is loaded, so no screen can
// touch storage before initialisation finishes.

final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final contentProvider = Provider<ContentCatalog>(
  (ref) => throw UnimplementedError('contentProvider must be overridden'),
);

final translationsProvider = Provider<Map<AppLanguage, Map<String, String>>>(
  (ref) => throw UnimplementedError('translationsProvider must be overridden'),
);

final clockProvider = Provider<Clock>((ref) => DateTime.now);

// Repositories: the only classes that run SQL.

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final progressRepositoryProvider = Provider(
  (ref) => ProgressRepository(
    ref.watch(databaseProvider),
    onProgressChanged: ref.watch(outboxRepositoryProvider).recordChange,
  ),
);

// Language and strings follow the session, so switching language rebuilds
// the UI without touching any progress state.

final languageProvider = Provider<AppLanguage>(
  (ref) => ref.watch(appSessionProvider).value?.language ?? AppLanguage.en,
);

final stringsProvider = Provider<AppStrings>(
  (ref) =>
      AppStrings(ref.watch(languageProvider), ref.watch(translationsProvider)),
);

/// The active profile's read-aloud choice. Off until a profile exists.
final readAloudProvider = Provider<ReadAloud>(
  (ref) => ref.watch(activeProfileProvider)?.readAloud ?? ReadAloud.off,
);
