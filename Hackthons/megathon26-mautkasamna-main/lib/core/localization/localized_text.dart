import '../errors/content_exception.dart';
import 'app_language.dart';

/// A piece of bilingual content as stored in the bundled JSON assets:
/// `{"en": "...", "te": "..."}`.
class LocalizedText {
  const LocalizedText({required this.en, required this.te});

  final String en;
  final String te;

  /// Parses `{"en": ..., "te": ...}`. Both languages are required so missing
  /// translations surface as content errors instead of blank UI.
  factory LocalizedText.fromJson(Object? json, String field) {
    if (json is! Map) {
      throw ContentException('"$field" must be an object with en/te text');
    }
    final en = json['en'];
    final te = json['te'];
    if (en is! String || en.trim().isEmpty) {
      throw ContentException('"$field" is missing English text');
    }
    if (te is! String || te.trim().isEmpty) {
      throw ContentException('"$field" is missing Telugu text');
    }
    return LocalizedText(en: en, te: te);
  }

  String of(AppLanguage language) => switch (language) {
    AppLanguage.en => en,
    AppLanguage.te => te,
  };
}
