import 'package:flutter/material.dart';

import '../core/game/game_style.dart';

/// Warm clay tones for a gullak (piggy bank), with a calm teal accent.
abstract final class GullakColors {
  static const clay = Toon.clay;
  static const teal = Toon.teal;
  static const success = Color(0xFF2E7D32);
  static const caution = Color(0xFFB26A00);
}

/// Spacing scale used across screens.
abstract final class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// One bright cartoon theme. The illustrations use a fixed palette, so the
/// app keeps the same look regardless of the system dark-mode setting.
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Toon.clay,
    primary: Toon.clay,
    secondary: Toon.teal,
    tertiary: Toon.gold,
    surface: Toon.cream,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Baloo',
  );
  TextStyle? bold(TextStyle? s, double weight) => s?.copyWith(
    fontFamily: 'Baloo',
    color: Toon.ink,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation('wght', weight)],
  );
  final text = base.textTheme.apply(
    bodyColor: Toon.ink,
    displayColor: Toon.ink,
  );
  final outline = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
    side: const BorderSide(color: Toon.ink, width: Toon.outline),
  );
  return base.copyWith(
    scaffoldBackgroundColor: Toon.cream,
    textTheme: text.copyWith(
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 17, height: 1.35),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.3),
      headlineMedium: bold(text.headlineMedium, 800),
      headlineSmall: bold(text.headlineSmall, 800),
      titleLarge: bold(text.titleLarge, 700),
      titleMedium: bold(text.titleMedium, 700),
      titleSmall: bold(text.titleSmall, 600),
      labelLarge: bold(text.labelLarge, 700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: outline,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: bold(const TextStyle(fontSize: 17), 700),
        shape: outline,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: Colors.white,
        foregroundColor: Toon.ink,
        textStyle: bold(const TextStyle(fontSize: 16), 700),
        side: const BorderSide(color: Toon.ink, width: Toon.outline),
        shape: outline,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: Toon.clayDark,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: const BorderSide(color: Toon.ink, width: 2),
      selectedColor: Toon.gold,
      backgroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Toon.ink, width: Toon.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Toon.ink, width: Toon.outline),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: Toon.cream, shape: outline),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
