import 'dart:ui' show Locale;

/// Languages the app ships with.
enum AppLanguage {
  en,
  te;

  String get code => name;

  Locale get locale => Locale(code);

  /// Falls back to English for unknown or missing codes so a corrupted
  /// preference can never block the app from starting.
  static AppLanguage fromCode(String? code) =>
      code == AppLanguage.te.code ? AppLanguage.te : AppLanguage.en;
}
