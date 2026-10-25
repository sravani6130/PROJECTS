import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../localization/app_language.dart';

/// How on-screen text is read out for a profile. On by default (slow), since
/// the app is built for students who find long reading hard.
enum ReadAloud {
  off,
  slow,
  normal;

  bool get enabled => this != off;

  static ReadAloud fromCode(String? code) =>
      values.where((r) => r.name == code).firstOrNull ?? ReadAloud.slow;
}

/// Speaks text aloud. One utterance at a time: a new one replaces the last.
abstract class Narrator {
  /// The text being spoken right now, or null when quiet.
  ValueListenable<String?> get speaking;

  Future<void> speak(String text, AppLanguage language, ReadAloud pace);

  Future<void> stop();

  /// Stops only if [text] is what is being spoken, so a screen that closes
  /// doesn't cut off the screen that replaced it.
  Future<void> stopIfSpeaking(String text) async {
    if (speaking.value == text) await stop();
  }

  /// Whether the phone has an offline voice for [language].
  Future<bool> hasVoice(AppLanguage language);
}

/// The phone's own text-to-speech engine, so it works offline and needs no
/// bundled audio. Failures (no engine, no voice) are silent: reading aloud is
/// a help, never a reason for a screen to break.
class TtsNarrator extends Narrator {
  TtsNarrator() {
    _tts.setCompletionHandler(_done);
    _tts.setCancelHandler(_done);
    _tts.setErrorHandler((_) => _done());
  }

  final _tts = FlutterTts();
  final _speaking = ValueNotifier<String?>(null);
  AppLanguage? _language;
  ReadAloud? _pace;

  @override
  ValueListenable<String?> get speaking => _speaking;

  void _done() => _speaking.value = null;

  static String _locale(AppLanguage language) => switch (language) {
    AppLanguage.en => 'en-IN',
    AppLanguage.te => 'te-IN',
  };

  @override
  Future<void> speak(String text, AppLanguage language, ReadAloud pace) async {
    final clean = cleanForSpeech(text);
    if (clean.isEmpty || !pace.enabled) return;
    try {
      if (_language != language) {
        await _tts.setLanguage(_locale(language));
        _language = language;
      }
      if (_pace != pace) {
        // Android's normal rate is 0.5.
        await _tts.setSpeechRate(pace == ReadAloud.slow ? 0.36 : 0.5);
        _pace = pace;
      }
      await _tts.stop();
      _speaking.value = text;
      await _tts.speak(clean);
    } catch (e) {
      debugPrint('Read aloud failed: $e');
      _done();
    }
  }

  @override
  Future<void> stop() async {
    _done();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<bool> hasVoice(AppLanguage language) async {
    try {
      // "Installed" means a downloaded voice; "available" would also accept
      // one that needs the internet, which this offline app can't count on.
      return await _tts.isLanguageInstalled(_locale(language)) == true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _tts.stop().ignore();
    _speaking.dispose();
  }
}

/// Keeps the words, drops symbols a voice would read out literally.
String cleanForSpeech(String text) => text
    .replaceAll(RegExp(r'[*_#•→←✓✔✗✘]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

final narratorProvider = Provider<Narrator>((ref) {
  final narrator = TtsNarrator();
  ref.onDispose(narrator.dispose);
  return narrator;
});
