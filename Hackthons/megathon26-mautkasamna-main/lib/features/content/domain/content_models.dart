import '../../../core/errors/content_exception.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/utils/json_reader.dart';

/// Starting level stored on a profile. Only one story exists for now.
enum Difficulty {
  easy,
  medium,
  advanced;

  static Difficulty parse(String value, String context) {
    for (final d in Difficulty.values) {
      if (d.name == value) return d;
    }
    throw ContentException('$context: unknown level "$value"');
  }
}

enum BadgeRuleType { completeAny, completeAll }

class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
    required this.ruleType,
    required this.missionIds,
  });

  factory BadgeDefinition.fromJson(JsonReader json) {
    final rule = json.object('rule');
    final type = switch (rule.string('type')) {
      'complete_any' => BadgeRuleType.completeAny,
      'complete_all' => BadgeRuleType.completeAll,
      final other => throw ContentException(
        '${rule.context}: unknown badge rule "$other"',
      ),
    };
    final missions = rule.stringList('missions');
    if (missions.isEmpty) {
      throw ContentException('${rule.context}.missions must not be empty');
    }
    return BadgeDefinition(
      id: json.string('id'),
      icon: json.string('icon'),
      name: json.text('name'),
      description: json.text('description'),
      ruleType: type,
      missionIds: missions,
    );
  }

  final String id;
  final String icon;
  final LocalizedText name;
  final LocalizedText description;
  final BadgeRuleType ruleType;
  final List<String> missionIds;
}

class SafetyTip {
  const SafetyTip({
    required this.icon,
    required this.title,
    required this.body,
  });

  factory SafetyTip.fromJson(JsonReader json) => SafetyTip(
    icon: json.string('icon'),
    title: json.text('title'),
    body: json.text('body'),
  );

  final String icon;
  final LocalizedText title;
  final LocalizedText body;
}

/// Everything loaded from the bundled JSON assets apart from text. The
/// story itself is code plus translated strings (`story/<code>.json`).
class ContentCatalog {
  ContentCatalog({required this.badges, required this.safetyTips});

  final List<BadgeDefinition> badges;
  final List<SafetyTip> safetyTips;

  BadgeDefinition? badgeById(String id) {
    for (final b in badges) {
      if (b.id == id) return b;
    }
    return null;
  }
}
