import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/story_driver.dart';
import '../helpers/test_support.dart';
import '../widget/app_flow_test.dart' show onboardAsGuest, tapKey;

/// Renders real screenshots for visual review:
///   flutter test test/shots --update-goldens --dart-define=SHOTS=true
void main() {
  const enabled = bool.fromEnvironment('SHOTS');

  /// Material icons are not bundled in tests; load them from the SDK so
  /// screenshots show real icons.
  Future<void> loadIcons() async {
    final icons = File(
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (!icons.existsSync()) return;
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/$name.png'),
    );
  }

  testWidgets('screens', (tester) async {
    await tester.runAsync(loadIcons);
    const lang = String.fromEnvironment('SHOT_LANG', defaultValue: 'lang_en');
    const small = bool.fromEnvironment('SHOT_SMALL');
    await pumpGullak(
      tester,
      logicalSize: small ? const Size(360, 640) : const Size(412, 892),
      textScale: small ? 1.3 : 1.0,
    );
    await onboardAsGuest(tester, lang: lang);
    await shot(tester, '00_map');
    await tapKey(tester, 'play_next');
    final driver = StoryDriver(
      tester,
      reckless: const bool.fromEnvironment('SHOT_RECKLESS'),
      onBeat: (label) => shot(tester, label),
    );
    for (var chapter = 1; chapter <= 7; chapter++) {
      await driver.playChapter();
      await shot(tester, 'c${chapter}_zz_complete');
      if (chapter < 7) await driver.tap('next_chapter');
    }
    await driver.tap('back_to_map');
    await shot(tester, '99_map_done');
  }, skip: !enabled);
}
