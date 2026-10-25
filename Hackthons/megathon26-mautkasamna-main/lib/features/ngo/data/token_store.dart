import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where student tokens are kept. Tokens are never written to SQLite, logs
/// or the UI.
abstract class TokenStore {
  Future<String?> read(String registrationKey);
  Future<void> write(String registrationKey, String token);
  Future<void> delete(String registrationKey);
  Future<void> deleteAll();
}

/// Android Keystore-backed storage (flutter_secure_storage).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _prefix = 'ngo_token_';

  @override
  Future<String?> read(String registrationKey) =>
      _storage.read(key: '$_prefix$registrationKey');

  @override
  Future<void> write(String registrationKey, String token) =>
      _storage.write(key: '$_prefix$registrationKey', value: token);

  @override
  Future<void> delete(String registrationKey) =>
      _storage.delete(key: '$_prefix$registrationKey');

  @override
  Future<void> deleteAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys.where((k) => k.startsWith(_prefix))) {
      await _storage.delete(key: key);
    }
  }
}

/// In-memory store for tests.
class MemoryTokenStore implements TokenStore {
  final tokens = <String, String>{};

  @override
  Future<String?> read(String registrationKey) async => tokens[registrationKey];

  @override
  Future<void> write(String registrationKey, String token) async =>
      tokens[registrationKey] = token;

  @override
  Future<void> delete(String registrationKey) async =>
      tokens.remove(registrationKey);

  @override
  Future<void> deleteAll() async => tokens.clear();
}
