import 'package:flutter/material.dart';

/// Shared colours for the cartoon art style. Every illustration uses this
/// palette so scenes, characters and UI look like one game.
abstract final class Toon {
  static const ink = Color(0xFF3B2A20); // outlines
  static const clay = Color(0xFFC8642E); // gullak / primary
  static const clayDark = Color(0xFF8F3F17);
  static const clayLight = Color(0xFFE89A5F);
  static const teal = Color(0xFF1F8A8A);
  static const tealDark = Color(0xFF125C5C);
  static const gold = Color(0xFFF5B82E);
  static const goldDark = Color(0xFFC98A0C);
  static const cream = Color(0xFFFFF6E5);
  static const leaf = Color(0xFF5DAE4B);
  static const leafDark = Color(0xFF3D7D33);
  static const sky = Color(0xFF8FD3F4);
  static const skyTop = Color(0xFF5BB8EA);
  static const berry = Color(0xFFD9475B);
  static const night = Color(0xFF243058);
  static const nightTop = Color(0xFF141B36);
  static const outline = 2.5;
}

/// Ambient looping motion (bobbing, drifting clouds) is switched off when the
/// device asks for reduced motion. One-shot reveals then appear instantly.
bool motionEnabled(BuildContext context) =>
    !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

/// Bold display style for game titles and buttons.
TextStyle toonTitle(BuildContext context, {double size = 22, Color? color}) =>
    TextStyle(
      fontFamily: 'Baloo',
      fontSize: size,
      height: 1.2,
      fontWeight: FontWeight.w800,
      fontVariations: const [FontVariation('wght', 800)],
      color: color ?? Toon.ink,
    );

/// Panel decoration with the thick cartoon outline and a hard drop shadow.
BoxDecoration toonPanel({
  Color color = Colors.white,
  double radius = 22,
  double shadow = 4,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Toon.ink, width: Toon.outline),
  boxShadow: [
    BoxShadow(
      color: Toon.ink.withValues(alpha: 0.85),
      offset: Offset(0, shadow),
    ),
  ],
);

/// Parses `#RRGGBB` from content JSON.
Color? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

Color darken(Color c, [double amount = 0.18]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}
