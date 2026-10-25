import '../errors/content_exception.dart';
import '../localization/localized_text.dart';

/// Typed, fail-fast access to a decoded JSON object. Every error names the
/// context (e.g. `M01.steps[0]`) so content authors can find the problem.
class JsonReader {
  JsonReader(Object? json, this.context) : _map = _asMap(json, context);

  final Map<String, Object?> _map;
  final String context;

  static Map<String, Object?> _asMap(Object? json, String context) {
    if (json is Map<String, Object?>) return json;
    if (json is Map) return json.cast<String, Object?>();
    throw ContentException('$context must be a JSON object');
  }

  bool has(String key) => _map[key] != null;

  String string(String key) {
    final value = _map[key];
    if (value is String && value.isNotEmpty) return value;
    throw ContentException('$context.$key must be a non-empty string');
  }

  String? optionalString(String key) {
    final value = _map[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  int integer(String key) {
    final value = _map[key];
    if (value is int) return value;
    throw ContentException('$context.$key must be an integer');
  }

  bool boolean(String key, {bool fallback = false}) {
    final value = _map[key];
    if (value == null) return fallback;
    if (value is bool) return value;
    throw ContentException('$context.$key must be true or false');
  }

  LocalizedText text(String key) =>
      LocalizedText.fromJson(_map[key], '$context.$key');

  LocalizedText? optionalText(String key) => has(key) ? text(key) : null;

  /// Raw nested object for presentation hints the domain does not interpret.
  Map<String, Object?>? optionalMap(String key) {
    final value = _map[key];
    if (value == null) return null;
    if (value is Map) return value.cast<String, Object?>();
    throw ContentException('$context.$key must be an object');
  }

  JsonReader object(String key) => JsonReader(_map[key], '$context.$key');

  List<T> list<T>(String key, T Function(JsonReader item) parse) {
    final value = _map[key];
    if (value is! List) {
      throw ContentException('$context.$key must be a list');
    }
    return [
      for (var i = 0; i < value.length; i++)
        parse(JsonReader(value[i], '$context.$key[$i]')),
    ];
  }

  List<String> stringList(String key) {
    final value = _map[key];
    if (value is List && value.every((e) => e is String)) {
      return value.cast<String>();
    }
    throw ContentException('$context.$key must be a list of strings');
  }

  Map<String, int> intMap(String key) {
    final value = _map[key];
    if (value is Map && value.values.every((v) => v is int)) {
      return value.map((k, v) => MapEntry(k as String, v as int));
    }
    throw ContentException('$context.$key must map ids to integers');
  }
}
