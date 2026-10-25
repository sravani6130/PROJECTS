import '../utils/template.dart';
import 'app_language.dart';

/// UI labels loaded from `assets/content/translations/<code>.json`.
///
/// Lookups fall back to English, then to the key itself, so a missing Telugu
/// string degrades gracefully. A unit test keeps both files in sync.
class AppStrings {
  const AppStrings(this.language, this._tables);

  final AppLanguage language;
  final Map<AppLanguage, Map<String, String>> _tables;

  String call(String key, [Map<String, Object> params = const {}]) {
    final raw = _tables[language]?[key] ?? _tables[AppLanguage.en]?[key] ?? key;
    return params.isEmpty ? raw : fillTemplate(raw, params);
  }

  AppStrings withLanguage(AppLanguage other) => AppStrings(other, _tables);
}
