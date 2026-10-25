import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gullak/core/utils/money_format.dart';
import 'package:gullak/core/utils/template.dart';
import 'package:gullak/features/content/domain/content_models.dart';
import 'package:gullak/features/story/domain/story_rules.dart';
import 'package:gullak/features/story/domain/story_script.dart';

import '../helpers/test_support.dart';
import 'story_rules_test.dart' show careful, playStory, reckless;

/// The "content validator": badges, story text and translations must be
/// complete in both languages and consistent with the script.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentCatalog content;

  Map<String, dynamic> read(String folder, String code) =>
      jsonDecode(File('assets/content/$folder/$code.json').readAsStringSync())
          as Map<String, dynamic>;

  /// Everything `t()` can look up for one language.
  Map<String, dynamic> table(String code) => {
    ...read('translations', code),
    ...read('story', code),
  };

  setUpAll(() async => content = await loadTestContent());

  test('badges refer to real chapters and every chapter earns one', () {
    final chapterIds = {for (final c in storyChapters) c.id};
    final rewarded = <String>{};
    expect(content.badges, isNotEmpty);
    for (final badge in content.badges) {
      expect(
        chapterIds.containsAll(badge.missionIds),
        isTrue,
        reason: badge.id,
      );
      rewarded.addAll(badge.missionIds);
    }
    expect(rewarded, chapterIds);
    expect(content.safetyTips, isNotEmpty);
  });

  test('no content contains a real http link', () {
    final dir = Directory('assets/content');
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      expect(
        file.readAsStringSync().contains(RegExp('https?://')),
        isFalse,
        reason: file.path,
      );
    }
  });

  group('story text', () {
    /// Every text key the script can show.
    Set<String> scriptKeys() {
      final keys = <String>{};
      for (final chapter in storyChapters) {
        keys
          ..add(chapter.titleKey)
          ..add(chapter.summaryKey);
        for (final beat in chapter.beats) {
          switch (beat) {
            case Talk():
              for (final line in beat.lines) {
                keys
                  ..add(line.text)
                  ..add('name_${line.who}');
              }
            case Pick():
              keys
                ..add(beat.prompt)
                ..add('name_${beat.who}');
              for (final option in beat.options) {
                keys
                  ..add(option.label)
                  ..add(option.result);
              }
            case Teach():
              keys.addAll(beat.points);
            case Recap():
              keys.addAll(beat.facts.map((f) => f.text));
            case Play():
              break;
          }
        }
      }
      for (final e in StoryRules.c1Items) {
        keys.addAll(['exp_${e.id}', 'c1_why_${e.id}']);
        if (e.need) keys.add('c1_missing_${e.id}');
      }
      for (final g in StoryRules.goals) {
        keys.add('goal_${g.id}');
      }
      return keys;
    }

    test('every key the script uses exists in both languages', () {
      for (final code in ['en', 'te']) {
        expect(
          scriptKeys().difference(table(code).keys.toSet()),
          isEmpty,
          reason: code,
        );
      }
    });

    test('every interpolated key in the activity screens exists', () {
      // Keys built at run time, e.g. t('c4_${m.id}_from').
      final en = table('en').keys.toSet();
      final expected = <String>{
        for (final m in StoryRules.scamAmounts.keys) ...[
          'c4_${m}_from',
          'c4_${m}_do',
          'c4_${m}_safe',
          'c4_${m}_ignore',
          'c4_${m}_proceed',
          for (var i = 0; i < 4; i++) 'c4_${m}_s$i',
        ],
        for (final d in ['verify', 'report', 'ignore']) 'c4_do_$d',
        for (final a in ['wait', 'tell', 'reply', 'bank', 'report'])
          'c4_rec_$a',
        for (final t in ['deposit', 'withdraw', 'upi']) ...[
          'c3_task_$t',
          'c3_act_$t',
        ],
        for (final r in ['verify', 'double', 'cash']) 'c3_res_$r',
        for (final o in ['wait', 'lite', 'nova']) ...[
          'c5_opt_$o',
          'c5_opt_${o}_d',
          'c5_wrap_$o',
        ],
        for (final m in ['debit', 'cash', 'credit']) ...[
          'c5_m_$m',
          'c5_prev_$m',
        ],
        for (final e in ['savings', 'break', 'family']) ...[
          'c6_evt_$e',
          'c6_evt_${e}_no',
          'c6_evt_${e}_r',
        ],
        for (final p in [
          'premium',
          'limit',
          'deductible',
          'exclusions',
          'covered',
          'excluded',
        ]) ...['c7_pol_$p', 'c7_pol_${p}_b'],
        for (final src in [
          'fund',
          'eatOut',
          'tv',
          'uncle',
          'power',
          'food',
        ]) ...['c7_src_$src', 'c7_src_${src}_d'],
        'c7_warn_power',
        'c7_warn_food',
        for (final n in ['c2_note_advance', 'c2_note_treat', 'c2_note_lab']) n,
      };
      expect(expected.difference(en), isEmpty);
      // Each message explains exactly three warning signs.
      for (final m in StoryRules.scamAmounts.keys) {
        expect(en.where((k) => k.startsWith('c4_${m}_k')), hasLength(3));
      }
    });

    test('text shown along both full play-throughs has no unfilled {…}', () {
      final placeholder = RegExp(r'\{\w+\}');
      for (final code in ['en', 'te']) {
        final strings = table(code);
        for (final policy in [careful, reckless]) {
          playStory(
            policy,
            onBeat: (s) {
              if (s.finished) return;
              final chapter = chapterByNumber(s.chapter);
              final params = StoryRules.params(s);
              // Check the beat about to be shown with the state it will see.
              final at = chapter.nextBeat(s, s.beat);
              if (at >= chapter.beats.length) return;
              final beat = chapter.beats[at];
              final keys = switch (beat) {
                Talk() => [
                  for (final line in beat.lines)
                    if (line.when?.call(s) ?? true) line.text,
                ],
                Pick() => [
                  beat.prompt,
                  for (final o in beat.options) ...[o.label, o.result],
                ],
                Teach() => beat.points,
                Recap() => [
                  for (final f in beat.facts)
                    if (f.when?.call(s) ?? true) f.text,
                ],
                Play() => const <String>[],
              };
              for (final key in keys) {
                final text = fillTemplate(strings[key] as String, params);
                expect(
                  placeholder.hasMatch(text),
                  isFalse,
                  reason: '$code $key: $text',
                );
              }
            },
          );
        }
      }
    });
  });

  group('translations', () {
    for (final folder in ['translations', 'story']) {
      test('$folder: English and Telugu have the same keys and no blanks', () {
        final en = read(folder, 'en');
        final te = read(folder, 'te');
        expect(te.keys.toSet(), en.keys.toSet());
        for (final entry in [...en.entries, ...te.entries]) {
          expect((entry.value as String).trim(), isNotEmpty, reason: entry.key);
        }
      });

      test('$folder: Telugu keeps the same placeholders as English', () {
        final en = read(folder, 'en');
        final te = read(folder, 'te');
        final ph = RegExp(r'\{\w+\}');
        for (final key in en.keys) {
          final a = ph.allMatches(en[key] as String).map((m) => m[0]).toSet();
          final b = ph.allMatches(te[key] as String).map((m) => m[0]).toSet();
          expect(b, a, reason: key);
        }
      });
    }

    test('UI and story files do not define the same key twice', () {
      expect(
        read(
          'translations',
          'en',
        ).keys.toSet().intersection(read('story', 'en').keys.toSet()),
        isEmpty,
      );
    });

    test('every literal key used in lib/ exists', () {
      final en = table('en').keys.toSet();
      final used = <String>{};
      final call = RegExp(r"\b(?:t|tx|guide|doneButton)\(\s*'([a-zA-Z0-9_]+)'");
      final literal = RegExp(
        r"'((?:error|verdict|notice_point|profile_name)_[a-z_]+)'",
      );
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        final src = file.readAsStringSync();
        used.addAll(call.allMatches(src).map((m) => m[1]!));
        used.addAll(literal.allMatches(src).map((m) => m[1]!));
      }
      expect(used.difference(en), isEmpty);
    });
  });

  group('formatting', () {
    test('Indian digit grouping', () {
      expect(formatAmount(0), '0');
      expect(formatAmount(999), '999');
      expect(formatAmount(1610), '1,610');
      expect(formatAmount(100000), '1,00,000');
      expect(formatAmount(12345678), '1,23,45,678');
      expect(formatAmount(-1500), '-1,500');
      expect(formatRupees(2000), '₹2,000');
    });

    test('template filling', () {
      expect(
        fillTemplate('₹{a} and {b}, {missing}', {'a': 1200, 'b': 'x'}),
        '₹1,200 and x, {missing}',
      );
    });
  });
}
