import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/errors/content_exception.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/utils/json_reader.dart';
import '../domain/content_models.dart';

/// Loads the read-only content bundled with the app.
class ContentRepository {
  ContentRepository(this._bundle, {this.root = 'assets/content'});

  final AssetBundle _bundle;
  final String root;

  /// Decoded manually rather than with `loadString`, which moves large
  /// strings to a background isolate (that stalls widget tests).
  Future<Object?> _loadJson(String path) async {
    final data = await _bundle.load('$root/$path');
    return jsonDecode(utf8.decode(data.buffer.asUint8List()));
  }

  Future<ContentCatalog> loadCatalog() async {
    final badges = JsonReader(
      await _loadJson('badges.json'),
      'badges',
    ).list('badges', BadgeDefinition.fromJson);
    final tips = JsonReader(
      await _loadJson('safety_tips.json'),
      'safety_tips',
    ).list('tips', SafetyTip.fromJson);
    return ContentCatalog(badges: badges, safetyTips: tips);
  }

  /// UI strings (`translations/<code>.json`) and story text
  /// (`story/<code>.json`) for one language, as one lookup table.
  Future<Map<String, String>> loadStrings(AppLanguage language) async {
    final table = <String, String>{};
    for (final path in [
      'translations/${language.code}.json',
      'story/${language.code}.json',
    ]) {
      final json = await _loadJson(path);
      if (json is! Map) throw ContentException('$path is invalid');
      table.addAll(json.map((k, v) => MapEntry(k as String, v as String)));
    }
    return table;
  }
}
