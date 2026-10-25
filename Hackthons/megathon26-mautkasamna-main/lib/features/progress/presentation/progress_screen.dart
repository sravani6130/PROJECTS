import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/game/characters.dart';
import '../../../core/game/game_widgets.dart';
import '../../../core/game/scenes.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/gullak_scaffold.dart';
import '../../story/application/story_controller.dart';
import '../../story/domain/story_script.dart';
import '../../story/domain/story_state.dart';
import '../../home/presentation/topic_card.dart';
import '../application/progress_providers.dart';
import '../domain/progress_models.dart';

/// Private progress overview: chapters, stars and badges. No ranking
/// or comparison with anyone else.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final language = ref.watch(languageProvider);
    final content = ref.watch(contentProvider);
    final async = ref.watch(progressSnapshotProvider);
    final theme = Theme.of(context);

    if (async.hasError && !async.hasValue) {
      return GullakScaffold(
        title: t('progress_title'),
        body: MessageView(
          icon: Icons.error_outline,
          message: t('error_generic'),
          action: FilledButton(
            onPressed: () => ref.invalidate(progressSnapshotProvider),
            child: Text(t('try_again')),
          ),
        ),
      );
    }
    final progress = async.value;
    if (progress == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final story =
        ref.watch(storySaveProvider).value?.state ?? const StoryState();
    final chaptersDone = storyChapters
        .where((c) => progress.mission(c.id).isCompleted)
        .length;
    final stars = storyChapters.fold(
      0,
      (sum, c) => sum + progress.mission(c.id).bestStars,
    );

    return GullakScaffold(
      title: t('progress_title'),
      scene: SceneKind.home,
      header: MascotHeader(
        text: t('badges_private'),
        mascot: const GullakMascot(mood: Mood.cheer),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Stat(
                key: const ValueKey('stat_missions'),
                label: t('stat_missions'),
                value: '$chaptersDone / ${storyChapters.length}',
                icon: Icons.flag_outlined,
              ),
              const SizedBox(width: Gap.sm),
              _Stat(
                label: t('stat_stars'),
                value: '$stars / ${storyChapters.length * 3}',
                icon: Icons.star_outline_rounded,
              ),
              const SizedBox(width: Gap.sm),
              _Stat(
                label: t('stat_badges'),
                value: '${progress.badgeIds.length}',
                icon: Icons.military_tech_outlined,
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Text(t('missions_heading'), style: theme.textTheme.titleLarge),
          const SizedBox(height: Gap.sm),
          for (final chapter in storyChapters)
            _ChapterRow(chapter: chapter, story: story, progress: progress),
          const SizedBox(height: Gap.lg),
          Text(t('badges_heading'), style: theme.textTheme.titleLarge),
          const SizedBox(height: Gap.sm),
          for (final badge in content.badges)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Opacity(
                opacity: progress.badgeIds.contains(badge.id) ? 1 : 0.5,
                child: SectionCard(
                  child: Row(
                    children: [
                      Icon(contentIcon(badge.icon), size: 32),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              badge.name.of(language),
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(badge.description.of(language)),
                          ],
                        ),
                      ),
                      progress.badgeIds.contains(badge.id)
                          ? StatusPill(
                              icon: Icons.check,
                              label: t('badge_owned'),
                              color: GullakColors.success,
                            )
                          : StatusPill(
                              icon: Icons.lock_outline,
                              label: t('badge_locked'),
                              color: theme.colorScheme.outline,
                            ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SectionCard(
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: Gap.xs),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, textAlign: TextAlign.center, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

class _ChapterRow extends ConsumerWidget {
  const _ChapterRow({
    required this.chapter,
    required this.story,
    required this.progress,
  });

  final Chapter chapter;
  final StoryState story;
  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final mission = progress.mission(chapter.id);
    final current = !story.finished && story.chapter == chapter.number;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${chapter.number}. ${t(chapter.titleKey)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (mission.isCompleted)
                  StarRow(stars: mission.bestStars, size: 20),
              ],
            ),
            Text(t(chapter.summaryKey)),
            const SizedBox(height: Gap.xs),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: [
                chapterStatusPill(
                  t,
                  mission,
                  locked: !story.finished && chapter.number > story.chapter,
                  started: current && story.beat > 0,
                ),
                if (mission.attemptCount > 0)
                  Text(t('attempts_n', {'n': mission.attemptCount})),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
