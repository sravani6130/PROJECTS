import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/audio/speak_button.dart';
import '../../../core/game/characters.dart';
import '../../../core/game/effects.dart';
import '../../../core/game/game_style.dart';
import '../../../core/game/game_tokens.dart';
import '../../../core/game/game_widgets.dart';
import '../../../core/game/props.dart';
import '../../../core/game/scenes.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/common.dart';
import '../application/story_controller.dart';
import '../domain/story_rules.dart';
import '../domain/story_script.dart';
import '../domain/story_state.dart';
import 'activities/activities.dart';
import 'story_widgets.dart';

/// Story text with the simulation's numbers filled in.
String storyText(
  AppStrings t,
  StoryState s,
  String key, [
  Map<String, Object> extra = const {},
]) => t(key, {...StoryRules.params(s), ...extra});

/// Plays one chapter of The Money Diaries: dialogue, activities, decisions,
/// the lesson and the recap, all on the shared game stage.
class ChapterScreen extends ConsumerStatefulWidget {
  const ChapterScreen({super.key, required this.number});

  final int number;

  @override
  ConsumerState<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends ConsumerState<ChapterScreen> {
  late Future<bool> _opening;

  @override
  void initState() {
    super.initState();
    _opening = Future.microtask(
      () => ref.read(storyControllerProvider.notifier).open(widget.number),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final play = ref.watch(storyControllerProvider);
    if (play == null || play.chapter.number != widget.number) {
      return FutureBuilder<bool>(
        future: _opening,
        builder: (context, snapshot) => Scaffold(
          appBar: AppBar(),
          body: snapshot.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : MessageView(
                  icon: Icons.lock_outline,
                  message: t('st_locked'),
                  action: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(t('back_to_map')),
                  ),
                ),
        ),
      );
    }

    final controller = ref.read(storyControllerProvider.notifier);
    final beat = play.beat;
    final sceneName = beat is Talk && beat.scene != null
        ? beat.scene
        : play.chapter.scene;
    final scene = SceneKind.parse(sceneName);
    final Widget body;
    if (play.isComplete) {
      body = _Completion(play: play);
    } else {
      body = switch (beat) {
        Talk() => _TalkView(
          key: ValueKey('beat_${play.state.beat}'),
          talk: beat,
          play: play,
        ),
        Pick() => _PickView(
          key: ValueKey('beat_${play.state.beat}'),
          pick: beat,
          play: play,
        ),
        Play() => KeyedSubtree(
          key: ValueKey('beat_${play.state.beat}'),
          child: buildActivity(
            beat.id,
            play.state,
            busy: play.busy,
            onDone: (result) => controller.complete(beat.id, result),
          ),
        ),
        Teach() => _TeachView(
          key: ValueKey('beat_${play.state.beat}'),
          teach: beat,
          play: play,
        ),
        Recap() => _WrapView(wrap: beat, play: play),
        null => _WrapView(wrap: const Recap([]), play: play),
      };
    }

    return Scaffold(
      backgroundColor: Toon.cream,
      body: SceneBackground(
        scene: scene,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _Hud(play: play, light: scene == SceneKind.night),
                  if (play.error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.md,
                        Gap.sm,
                        Gap.md,
                        0,
                      ),
                      child: NoticeBanner(
                        icon: Icons.error_outline,
                        text: t(
                          play.error == StoryError.saveFailed
                              ? 'error_save'
                              : 'error_invalid_choice',
                        ),
                      ),
                    ),
                  Expanded(child: body),
                ],
              ),
            ),
            if (play.isComplete)
              const Positioned.fill(child: IgnorePointer(child: Confetti())),
          ],
        ),
      ),
    );
  }
}

class _Hud extends ConsumerWidget {
  const _Hud({required this.play, required this.light});

  final StoryPlay play;
  final bool light;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = play.state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RoundGameButton(back: true),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('st_chapter_n', {
                        'n': play.chapter.number,
                        'title': t(play.chapter.titleKey),
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: toonTitle(
                        context,
                        size: 17,
                        color: light ? Colors.white : Toon.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      label: t('st_chapter_progress'),
                      value: '${(play.progress * 100).round()}%',
                      child: Meter(
                        value: play.isComplete ? 1 : play.progress,
                        height: 12,
                        color: Toon.gold,
                      ),
                    ),
                  ],
                ),
              ),
              if (play.practice) ...[
                const SizedBox(width: Gap.sm),
                TagLabel(t('st_practice')),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                MoneyChip(
                  key: const ValueKey('chip_wallet'),
                  label: t('st_wallet'),
                  amount: s.wallet,
                  prop: PropKind.coin,
                ),
                const SizedBox(width: 6),
                if (play.chapter.number < 3 || s.jar > 0) ...[
                  MoneyChip(
                    key: const ValueKey('chip_jar'),
                    label: t('st_jar'),
                    amount: s.jar,
                    prop: PropKind.jar,
                  ),
                  const SizedBox(width: 6),
                ],
                if (play.chapter.number >= 3) ...[
                  MoneyChip(
                    key: const ValueKey('chip_bank'),
                    label: t('st_bank'),
                    amount: s.bank,
                    prop: PropKind.bank,
                  ),
                  const SizedBox(width: 6),
                ],
                if (s.fd > 0) ...[
                  MoneyChip(
                    label: t('st_fd'),
                    amount: s.fd,
                    prop: PropKind.lock,
                  ),
                  const SizedBox(width: 6),
                ],
                if (s.debt > 0)
                  MoneyChip(
                    key: const ValueKey('chip_debt'),
                    label: t('st_owed'),
                    amount: s.debt,
                    prop: PropKind.card,
                    color: const Color(0xFFFFD9D9),
                  ),
                if (s.goalTarget > 0 && s.debt == 0)
                  MoneyChip(
                    label: t('st_goal'),
                    amount: s.goalTarget,
                    prop: PropKind.parse(
                      StoryRules.goals
                          .where((g) => g.id == s.goalId)
                          .firstOrNull
                          ?.prop,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual-novel style conversation: one speaker at a time, tap to continue.
class _TalkView extends ConsumerStatefulWidget {
  const _TalkView({super.key, required this.talk, required this.play});

  final Talk talk;
  final StoryPlay play;

  @override
  ConsumerState<_TalkView> createState() => _TalkViewState();
}

class _TalkViewState extends ConsumerState<_TalkView> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final s = widget.play.state;
    final lines = [
      for (final line in widget.talk.lines)
        if (line.when?.call(s) ?? true) line,
    ];
    final controller = ref.read(storyControllerProvider.notifier);
    if (lines.isEmpty) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: GameButton(
            key: const ValueKey('story_next'),
            label: t('continue'),
            onPressed: () => controller.advance(widget.play.state.beat),
          ),
        ),
      );
    }
    final line = lines[min(_index, lines.length - 1)];
    final last = _index >= lines.length - 1;
    final name = t('name_${line.who}');
    final screen = MediaQuery.sizeOf(context);
    final figureHeight = (screen.height * 0.34).clamp(150.0, 320.0);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: LayoutBuilder(
                    builder: (context, box) => SpeechBubble(
                      text: storyText(t, s, line.text),
                      speaker: name,
                      tail: TailSide.bottom,
                      textKey: const ValueKey('story_line'),
                      maxHeight: max(48, box.maxHeight - 64),
                    ),
                  ),
                ),
                SizedBox(
                  height: figureHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: min(screen.width * 0.42, 190),
                        child: CastFigure(
                          key: ValueKey(line.who),
                          who: line.who,
                          mood: moodOf(line.mood),
                          talking: true,
                          label: name,
                        ),
                      ),
                      const Spacer(),
                      // Asha listens when someone else is speaking.
                      if (line.who != 'asha')
                        SizedBox(
                          width: min(screen.width * 0.26, 110),
                          height: figureHeight * 0.7,
                          child: const ExcludeSemantics(
                            child: CastFigure(who: 'asha'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              Text(
                '${min(_index, lines.length - 1) + 1}/${lines.length}',
                style: toonTitle(context, size: 14),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: GameButton(
                  key: const ValueKey('story_next'),
                  label: t(last ? 'continue' : 'next'),
                  icon: Icons.arrow_forward_rounded,
                  busy: widget.play.busy,
                  onPressed: () {
                    tapFeedback();
                    if (last) {
                      controller.advance(s.beat);
                    } else {
                      setState(() => _index++);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A decision: choose, commit, see the consequence, then move on.
class _PickView extends ConsumerStatefulWidget {
  const _PickView({super.key, required this.pick, required this.play});

  final Pick pick;
  final StoryPlay play;

  @override
  ConsumerState<_PickView> createState() => _PickViewState();
}

class _PickViewState extends ConsumerState<_PickView> {
  String? _selected;
  Opt? _committed;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final s = widget.play.state;
    final pick = widget.pick;
    final committed = _committed;
    final controller = ref.read(storyControllerProvider.notifier);
    final tone = committed == null ? Tone.okay : toneOf(committed.tone);

    return BeatLayout(
      guide: GuideStrip(
        who: pick.who,
        speaker: t('name_${pick.who}'),
        text: storyText(t, s, pick.prompt),
        mood: committed == null
            ? Mood.thinking
            : switch (tone) {
                Tone.best => Mood.cheer,
                Tone.okay => Mood.happy,
                Tone.risky => Mood.worried,
              },
      ),
      panel: committed != null
          ? ToneBanner(
              key: const ValueKey('pick_result'),
              tone: tone,
              title: t(switch (tone) {
                Tone.best => 'verdict_best',
                Tone.okay => 'verdict_neutral',
                Tone.risky =>
                  committed.retry ? 'verdict_retry' : 'verdict_neutral',
              }),
              text: storyText(t, s, committed.result),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final opt in pick.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Opacity(
                      opacity: (opt.enabled?.call(s) ?? true) ? 1 : 0.45,
                      child: ChoiceTile(
                        key: ValueKey('opt_${opt.id}'),
                        label: storyText(t, s, opt.label),
                        prop: opt.prop == null
                            ? null
                            : PropKind.parse(opt.prop),
                        selected: _selected == opt.id,
                        onTap: () {
                          if (!(opt.enabled?.call(s) ?? true)) return;
                          tapFeedback();
                          setState(() => _selected = opt.id);
                        },
                      ),
                    ),
                  ),
              ],
            ),
      bottom: committed == null
          ? GameButton(
              key: const ValueKey('pick_confirm'),
              label: t('st_decide'),
              onPressed: _selected == null
                  ? null
                  : () {
                      final opt = pick.options.firstWhere(
                        (o) => o.id == _selected,
                      );
                      opt.tone == 'risky' ? warnFeedback() : successFeedback();
                      setState(() => _committed = opt);
                    },
            )
          : committed.retry
          ? GameButton(
              key: const ValueKey('pick_retry'),
              label: t('try_different_choice'),
              style: GameButtonStyle.secondary,
              onPressed: () => setState(() {
                _committed = null;
                _selected = null;
              }),
            )
          : GameButton(
              key: const ValueKey('story_next'),
              label: t('continue'),
              busy: widget.play.busy,
              onPressed: () =>
                  controller.complete(pick.id, {'option': committed.id}),
            ),
    );
  }
}

/// Gullu's lesson card: the idea behind what just happened.
class _TeachView extends ConsumerWidget {
  const _TeachView({super.key, required this.teach, required this.play});

  final Teach teach;
  final StoryPlay play;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final points = [
      for (final key in teach.points) storyText(t, play.state, key),
    ];
    return BeatLayout(
      guide: GuideStrip(
        who: 'gullu',
        speaker: t('name_gullu'),
        text: t('what_this_teaches'),
        spokenText: [t('what_this_teaches'), ...points].join('\n'),
        mood: Mood.cheer,
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < teach.points.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PopIn(
                delay: Duration(milliseconds: 120 * i),
                child: GameCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Toon.teal,
                        child: Text(
                          '${i + 1}',
                          style: toonTitle(
                            context,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          points[i],
                          style: const TextStyle(fontSize: 16, height: 1.3),
                        ),
                      ),
                      SpeakButton(text: points[i], size: 32),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottom: GameButton(
        key: const ValueKey('story_next'),
        label: t('continue'),
        busy: play.busy,
        onPressed: () =>
            ref.read(storyControllerProvider.notifier).advance(play.state.beat),
      ),
    );
  }
}

/// Chapter recap: where the money stands before the chapter closes.
class _WrapView extends ConsumerWidget {
  const _WrapView({required this.wrap, required this.play});

  final Recap wrap;
  final StoryPlay play;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = play.state;
    final facts = [
      for (final fact in wrap.facts)
        if (fact.when?.call(s) ?? true) storyText(t, s, fact.text),
    ];
    return BeatLayout(
      guide: GuideStrip(
        who: 'asha',
        speaker: t('name_asha'),
        text: t('st_diary_entry'),
        spokenText: [t('st_diary_entry'), t('st_recap'), ...facts].join('\n'),
        mood: Mood.happy,
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('st_recap'), style: toonTitle(context, size: 19)),
          const SizedBox(height: Gap.sm),
          for (final fact in facts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.edit_note_rounded, color: Toon.clayDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      fact,
                      style: const TextStyle(fontSize: 16, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Gap.sm),
          NoticeBanner(
            icon: Icons.info_outline,
            text: t(play.practice ? 'st_practice_note' : 'pretend_money_short'),
          ),
        ],
      ),
      bottom: GameButton(
        key: const ValueKey('finish_chapter'),
        label: t('st_finish_chapter'),
        icon: Icons.flag_rounded,
        busy: play.busy,
        onPressed: ref.read(storyControllerProvider.notifier).finish,
      ),
    );
  }
}

class _Completion extends ConsumerWidget {
  const _Completion({required this.play});

  final StoryPlay play;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final language = ref.watch(languageProvider);
    final content = ref.watch(contentProvider);
    final number = play.chapter.number;
    final isLast = number >= StoryState.chapterCount;
    final s = play.state;
    final ending = <String>[
      if (isLast) ...[
        'end_fair',
        switch (s.flag('c5_item')) {
          'nova' => 'end_nova',
          'lite' => 'end_lite',
          _ => 'end_wait',
        },
        s.debt > 0 ? 'end_debt' : 'end_no_debt',
        s.n('c4_unsafe') > 0 ? 'end_scam_learned' : 'end_scam_safe',
        'end_saved',
      ],
    ];
    final endingText = [for (final key in ending) storyText(t, s, key)];
    return BeatLayout(
      guide: GuideStrip(
        who: 'gullu',
        speaker: t('name_gullu'),
        text: t(isLast ? 'st_story_done' : 'st_chapter_done'),
        spokenText: [
          t(isLast ? 'st_story_done' : 'st_chapter_done'),
          if (endingText.isNotEmpty) t('end_title'),
          ...endingText,
        ].join('\n'),
        mood: Mood.cheer,
      ),
      panel: Column(
        children: [
          PopIn(child: StarRow(stars: play.completedStars ?? 1, size: 44)),
          const SizedBox(height: 4),
          Text(
            t('st_stars_note'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            t(play.chapter.titleKey),
            key: const ValueKey('chapter_complete'),
            textAlign: TextAlign.center,
            style: toonTitle(context, size: 20),
          ),
          Text(t('saved_on_device'), textAlign: TextAlign.center),
          for (final id in play.newBadgeIds)
            if (content.badgeById(id) case final badge?)
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm),
                child: PopIn(
                  child: TagLabel(
                    t('badge_earned', {'name': badge.name.of(language)}),
                  ),
                ),
              ),
          if (ending.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            GameCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t('end_title'), style: toonTitle(context, size: 18)),
                  for (final line in endingText)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        line,
                        style: const TextStyle(fontSize: 15, height: 1.3),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (play.practice) ...[
            const SizedBox(height: Gap.sm),
            Text(t('st_practice_note'), textAlign: TextAlign.center),
          ],
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isLast && !play.practice) ...[
            GameButton(
              key: const ValueKey('next_chapter'),
              icon: Icons.play_arrow_rounded,
              label: t('st_next_chapter', {'title': t('c${number + 1}_title')}),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => ChapterScreen(number: number + 1),
                ),
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],
          GameButton(
            key: const ValueKey('back_to_map'),
            label: t('back_to_map'),
            style: GameButtonStyle.plain,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
