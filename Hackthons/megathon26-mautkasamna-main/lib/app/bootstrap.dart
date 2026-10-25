import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:sqflite/sqflite.dart';

import '../core/localization/app_language.dart';
import '../data/database/app_database.dart';
import '../features/content/data/content_repository.dart';
import '../features/content/domain/content_models.dart';
import 'app.dart';
import 'providers.dart';
import 'theme.dart';

/// Everything that must be ready before the first screen: the database and
/// the bundled content. Loaded once per app start.
class AppServices {
  const AppServices({
    required this.database,
    required this.content,
    required this.translations,
  });

  final Database database;
  final ContentCatalog content;
  final Map<AppLanguage, Map<String, String>> translations;

  static Future<AppServices> load({
    AssetBundle? bundle,
    Future<Database> Function()? openDatabase,
  }) async {
    final repo = ContentRepository(bundle ?? rootBundle);
    final database = await (openDatabase ?? AppDatabase.open)();
    return AppServices(
      database: database,
      content: await repo.loadCatalog(),
      translations: {
        for (final language in AppLanguage.values)
          language: await repo.loadStrings(language),
      },
    );
  }

  List<Override> get overrides => [
    databaseProvider.overrideWithValue(database),
    contentProvider.overrideWithValue(content),
    translationsProvider.overrideWithValue(translations),
  ];
}

/// Initialises storage and content, then starts the app. Shows a retry
/// screen if initialisation fails instead of crashing.
class GullakBootstrap extends StatefulWidget {
  const GullakBootstrap({super.key});

  @override
  State<GullakBootstrap> createState() => _GullakBootstrapState();
}

class _GullakBootstrapState extends State<GullakBootstrap> {
  late Future<AppServices> _services = AppServices.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _services,
      builder: (context, snapshot) {
        final services = snapshot.data;
        if (services != null) {
          return ProviderScope(
            overrides: services.overrides,
            // Errors are shown with a "Try again" action instead of silent
            // automatic retries.
            retry: (_, _) => null,
            child: const GullakApp(),
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: Scaffold(
            body: snapshot.hasError
                ? _StartupError(
                    onRetry: () =>
                        setState(() => _services = AppServices.load()),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  // Translations may be what failed to load, so this one message is inline
  // in both languages.
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: Gap.md),
            const Text(
              'Gullak could not start. Your saved progress is safe.\n'
              'గుల్లక్ ప్రారంభం కాలేదు. మీ ప్రోగ్రెస్ సురక్షితంగా ఉంది.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.lg),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try again / మళ్లీ ప్రయత్నించండి'),
            ),
          ],
        ),
      ),
    );
  }
}
