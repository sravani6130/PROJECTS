import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

/// Opens the single app database. Call once at startup and share the handle
/// through Riverpod; widgets never open connections themselves.
class AppDatabase {
  const AppDatabase._();

  static const fileName = 'gullak.db';

  /// [factory] and [path] are injectable so tests can use an in-memory FFI
  /// database; production uses sqflite's platform factory and app storage.
  static Future<Database> open({
    DatabaseFactory? factory,
    String? path,
    List<Migration> migrations = appMigrations,
  }) async {
    checkMigrations(migrations);
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    return dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: migrations.length,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) =>
            runMigrations(db, from: 0, to: version, migrations: migrations),
        onUpgrade: (db, from, to) =>
            runMigrations(db, from: from, to: to, migrations: migrations),
      ),
    );
  }
}
