import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/audio/speak_button.dart';
import '../../../core/game/characters.dart';
import '../../../core/game/game_style.dart';
import '../../../core/game/props.dart';
import '../../../core/game/scenes.dart';
import '../../../core/widgets/gullak_scaffold.dart';
import '../../story/presentation/story_widgets.dart';
import '../application/daily_providers.dart';
import '../domain/daily_rules.dart';
import '../domain/inbox.dart';

/// In-app notifications: check-ins, streaks, finished chapters and badges.
/// Opening it marks everything as read.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  @override
  void initState() {
    super.initState();
    // The list loads first, so new messages still show as new this time.
    Future.microtask(() => ref.read(dailyActionsProvider).markInboxRead());
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final messages = ref.watch(inboxProvider).value;
    final today = DailyRules.dayKey(ref.read(clockProvider)());

    return GullakScaffold(
      title: t('inbox_title'),
      scene: SceneKind.home,
      body: messages == null
          ? const Center(child: CircularProgressIndicator())
          : messages.isEmpty
          ? Column(
              children: [
                const SizedBox(height: Gap.lg),
                const SizedBox(
                  height: 120,
                  child: GullakMascot(mood: Mood.happy),
                ),
                const SizedBox(height: Gap.md),
                Text(
                  t('inbox_empty'),
                  key: const ValueKey('inbox_empty'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.3),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final m in messages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MessageTile(message: m, today: today),
                  ),
              ],
            ),
    );
  }
}

class _MessageTile extends ConsumerWidget {
  const _MessageTile({required this.message, required this.today});

  final InboxMessage message;
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final text = inboxText(
      t,
      message,
      badgeName: (id) => ref
          .read(contentProvider)
          .badgeById(id)
          ?.name
          .of(ref.read(languageProvider)),
    );
    final day = DailyRules.dayKey(message.createdAt);
    final when = switch (DailyRules.daysBetween(day, today)) {
      0 => t('inbox_today'),
      1 => t('inbox_yesterday'),
      _ => day,
    };
    final prop = switch (message.kind) {
      InboxKind.checkIn => PropKind.coin,
      InboxKind.streak || InboxKind.weekBonus => PropKind.gift,
      InboxKind.chapterDone || InboxKind.storyDone => PropKind.notebook,
      InboxKind.badge => PropKind.shield,
    };
    return GameCard(
      color: message.read ? Colors.white : const Color(0xFFFFF1C9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PropIcon(prop, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 15, height: 1.3)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      when,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Toon.clayDark,
                      ),
                    ),
                    if (!message.read) ...[
                      const SizedBox(width: 6),
                      TagLabel(t('inbox_new')),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SpeakButton(text: text, size: 30),
        ],
      ),
    );
  }
}
