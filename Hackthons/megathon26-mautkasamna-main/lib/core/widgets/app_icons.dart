import 'package:flutter/material.dart';

/// Maps icon ids used in JSON content to bundled Material icons, so content
/// never depends on remote images.
IconData contentIcon(String id) => switch (id) {
  'wallet' => Icons.account_balance_wallet_outlined,
  'savings' => Icons.savings_outlined,
  'growth' => Icons.trending_up,
  'shield' => Icons.shield_outlined,
  'star' => Icons.star_outline,
  'lock' => Icons.lock_outline,
  'timer' => Icons.timer_outlined,
  'link_off' => Icons.link_off,
  'verified' => Icons.verified_user_outlined,
  'report' => Icons.report_outlined,
  'rocket' => Icons.rocket_launch_outlined,
  'leaf' => Icons.eco_outlined,
  'book' => Icons.menu_book_outlined,
  'music' => Icons.music_note_outlined,
  'bolt' => Icons.bolt_outlined,
  _ => Icons.circle_outlined,
};
