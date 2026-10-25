import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/game/characters.dart';
import '../../../core/game/game_style.dart';
import '../../../core/game/game_widgets.dart';
import '../../../core/game/props.dart';
import '../../../core/game/scenes.dart';
import '../../daily/application/daily_providers.dart';
import '../../daily/presentation/daily_card.dart';
import '../../ngo/presentation/ngo_widgets.dart';
import '../../onboarding/presentation/level_select_screen.dart';
import '../../profiles/application/app_session_controller.dart';
import '../../profiles/presentation/profile_form.dart';
import '../../progress/application/progress_providers.dart';
import '../../progress/domain/progress_models.dart';
import '../../progress/presentation/progress_screen.dart';
import '../../safety/presentation/stay_safe_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../story/application/story_controller.dart';
import '../../story/domain/story_script.dart';
import '../../story/domain/story_state.dart';
import '../../story/presentation/chapter_screen.dart';
import 'topic_card.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// The story map: one illustrated zone per chapter of The Money Diaries,
/// joined by a winding path. Chapters unlock in order.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final profile = ref.watch(activeProfileProvider);
    final progress =
        ref.watch(progressSnapshotProvider).value ?? ProgressSnapshot.empty;
    final story =
        ref.watch(storySaveProvider).value?.state ?? const StoryState();
    final next = story.finished ? null : chapterByNumber(story.chapter);
    final done = storyChapters
        .where((c) => progress.mission(c.id).isCompleted)
        .length;
    final look =
        CharacterLook.avatars[profile?.avatarId] ??
        CharacterLook.avatars['star']!;
    // Keeps the phone's daily reminders matched to today's progress.
    ref.watch(reminderSyncProvider);

    return Scaffold(
      backgroundColor: Toon.cream,
      body: Stack(
        children: [
          // The map scrolls below the HUD so nothing is hidden under it.
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: toonPanel(color: Toon.cream),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFBFE8FF),
                              border: Border.all(color: Toon.ink, width: 2.5),
                            ),
                            child: ClipOval(child: CartoonFace(look: look)),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('hello_name', {
                                  'name': profile == null
                                      ? ''
                                      : profileDisplayName(profile, t),
                                }),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: toonTitle(context, size: 19),
                              ),
                              Text(
                                t('st_chapters_done', {
                                  'done': done,
                                  'total': storyChapters.length,
                                }),
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: done / storyChapters.length,
                                  minHeight: 8,
                                  color: Toon.leaf,
                                  backgroundColor: Colors.black12,
                                ),
                              ),
                              // NGO sync state; nothing when not linked.
                              const SyncChip(),
                            ],
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        RoundGameButton(
                          key: const ValueKey('open_progress'),
                          tooltip: t('progress_title'),
                          icon: Icons.emoji_events_rounded,
                          onPressed: () =>
                              _push(context, const ProgressScreen()),
                        ),
                        const SizedBox(width: Gap.sm),
                        RoundGameButton(
                          key: const ValueKey('open_settings'),
                          tooltip: t('settings_title'),
                          icon: Icons.settings_rounded,
                          onPressed: () =>
                              _push(context, const SettingsScreen()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ClipRect(
                  child: CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: DailyCard()),
                      SliverToBoxAdapter(
                        child: _StoryBanner(
                          title: t('st_story_title'),
                          text: t('st_story_blurb'),
                          level: t('level_easy'),
                          levelsLabel: t('levels_open'),
                        ),
                      ),
                      for (final chapter in storyChapters)
                        SliverToBoxAdapter(
                          child: _Zone(
                            chapter: chapter,
                            story: story,
                            progress: progress,
                            playerLook: look,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: Gap.md,
            right: Gap.md,
            bottom: Gap.md,
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StaySafeButton(label: t('stay_safe_title')),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: next == null
                        ? GameButton(
                            label: t('view_progress'),
                            icon: Icons.emoji_events_rounded,
                            style: GameButtonStyle.secondary,
                            onPressed: () =>
                                _push(context, const ProgressScreen()),
                          )
                        : GameButton(
                            key: const ValueKey('play_next'),
                            icon: Icons.play_arrow_rounded,
                            label: t('continue_with', {
                              'title': t(next.titleKey),
                            }),
                            onPressed: () => _push(
                              context,
                              ChapterScreen(number: next.number),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// PIN/OTP safety is always one tap away.
class _StaySafeButton extends StatelessWidget {
  const _StaySafeButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('stay_safe_banner'),
        onTap: () => _push(context, const StaySafeScreen()),
        child: Container(
          width: 78,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: toonPanel(color: Toon.teal, radius: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PropIcon(PropKind.shield, size: 34),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.1,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Zone extends ConsumerWidget {
  const _Zone({
    required this.chapter,
    required this.story,
    required this.progress,
    required this.playerLook,
  });

  final Chapter chapter;
  final StoryState story;
  final ProgressSnapshot progress;
  final CharacterLook playerLook;

  static const _banner = 84.0;
  static const _height = 300.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final node = Offset(
            chapter.number.isOdd ? w * 0.3 : w * 0.7,
            _banner + 60,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: SceneBackground(scene: SceneKind.parse(chapter.scene)),
              ),
              // Soft wash so nodes and labels stay readable on any scene.
              Positioned.fill(
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.18)),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _PathPainter([
                    Offset(w * 0.5, 0),
                    node,
                    Offset(w * 0.5, _height),
                  ]),
                ),
              ),
              Positioned(
                left: Gap.md,
                right: Gap.md,
                top: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: toonPanel(color: Toon.clay, radius: 14),
                    child: Text(
                      t('st_chapter_short', {'n': chapter.number}),
                      style: toonTitle(context, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: node.dx - w * 0.28,
                width: w * 0.56,
                top: node.dy - 44,
                child: _ChapterNode(
                  chapter: chapter,
                  story: story,
                  progress: progress,
                  playerLook: playerLook,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      path.cubicTo(
        a.dx,
        (a.dy + b.dy) / 2,
        b.dx,
        (a.dy + b.dy) / 2,
        b.dx,
        b.dy,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Toon.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFF3DDB0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round,
    );
    // Dashes down the middle of the trail.
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 22) {
        canvas.drawPath(
          metric.extractPath(d, min(d + 10, metric.length)),
          Paint()
            ..color = Toon.clayLight
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.points != points;
}

class _ChapterNode extends ConsumerWidget {
  const _ChapterNode({
    required this.chapter,
    required this.story,
    required this.progress,
    required this.playerLook,
  });

  final Chapter chapter;
  final StoryState story;
  final ProgressSnapshot progress;
  final CharacterLook playerLook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final mission = progress.mission(chapter.id);
    final isNext = !story.finished && story.chapter == chapter.number;
    final locked = !story.finished && chapter.number > story.chapter;
    final started = isNext && story.beat > 0;
    final color = mission.isCompleted
        ? Toon.gold
        : started
        ? Toon.clayLight
        : locked
        ? const Color(0xFFE3E0DA)
        : Colors.white;

    return Semantics(
      button: true,
      label: '${chapter.number}. ${t(chapter.titleKey)}',
      child: GestureDetector(
        key: ValueKey('chapter_${chapter.number}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (locked) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(t('st_locked'))));
            return;
          }
          _push(context, ChapterScreen(number: chapter.number));
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: Toon.ink,
                      width: isNext ? 4 : Toon.outline,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Toon.ink, offset: Offset(0, 5)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: locked
                      ? const Icon(
                          Icons.lock_rounded,
                          size: 34,
                          color: Toon.ink,
                        )
                      : Text(
                          '${chapter.number}',
                          style: toonTitle(context, size: 32),
                        ),
                ),
                if (isNext)
                  Positioned(
                    top: -42,
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: _Bounce(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFBFE8FF),
                            border: Border.all(color: Toon.ink, width: 2.5),
                          ),
                          child: ClipOval(child: CartoonFace(look: playerLook)),
                        ),
                      ),
                    ),
                  ),
                if (mission.isCompleted)
                  Positioned(
                    bottom: -12,
                    child: Row(
                      children: [
                        for (var i = 0; i < 3; i++)
                          Icon(
                            i < mission.bestStars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 24,
                            color: Toon.goldDark,
                            shadows: const [
                              Shadow(color: Colors.white, blurRadius: 4),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: toonPanel(color: Toon.cream, radius: 12, shadow: 2),
              child: Column(
                children: [
                  Text(
                    t(chapter.titleKey),
                    textAlign: TextAlign.center,
                    style: toonTitle(context, size: 15),
                  ),
                  chapterStatusPill(
                    t,
                    mission,
                    locked: locked,
                    started: started,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gentle bounce for the "you are here" marker.
class _Bounce extends StatefulWidget {
  const _Bounce({required this.child});

  final Widget child;

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionEnabled(context)) {
      _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
      child: child,
    ),
    child: widget.child,
  );
}

class _StoryBanner extends StatelessWidget {
  const _StoryBanner({
    required this.title,
    required this.text,
    required this.level,
    required this.levelsLabel,
  });

  final String title;
  final String text;

  /// The level these chapters belong to; tapping it shows all levels.
  final String level;
  final String levelsLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: toonPanel(color: const Color(0xFFFFF1C9)),
        child: Row(
          children: [
            const PropIcon(PropKind.notebook, size: 46),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(title, style: toonTitle(context, size: 19)),
                      _LevelTag(level: level, label: levelsLabel),
                    ],
                  ),
                  Text(text, style: const TextStyle(height: 1.25)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Easy ›" tag that reopens the level screen.
class _LevelTag extends StatelessWidget {
  const _LevelTag({required this.level, required this.label});

  final String level;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $level',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('open_levels'),
        behavior: HitTestBehavior.opaque,
        onTap: () => openLevelSelect(context),
        // Taller than the tag so it is easy to hit.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
            decoration: toonPanel(color: Toon.gold, radius: 12, shadow: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(level, style: toonTitle(context, size: 14)),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
