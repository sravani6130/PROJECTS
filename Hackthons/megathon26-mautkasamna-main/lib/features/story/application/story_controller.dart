import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../daily/application/daily_providers.dart';
import '../../ngo/application/ngo_providers.dart';
import '../../profiles/application/app_session_controller.dart';
import '../../progress/application/progress_providers.dart';
import '../../progress/domain/badge_rules.dart';
import '../data/story_repository.dart';
import '../domain/story_rules.dart';
import '../domain/story_script.dart';
import '../domain/story_state.dart';

final storyRepositoryProvider = Provider(
  (ref) => StoryRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
    // Queues the NGO progress report in the same transaction as the save.
    onProgressChanged: ref.watch(outboxRepositoryProvider).recordChange,
  ),
);

/// The active profile's saved story (for the chapter map). Invalidate after
/// any story write.
final storySaveProvider = FutureProvider<StorySave?>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return null;
  return ref.watch(storyRepositoryProvider).load(profileId);
});

enum StoryError { saveFailed, invalid }

/// What the chapter screen shows.
class StoryPlay {
  const StoryPlay({
    required this.chapter,
    required this.state,
    required this.revision,
    required this.practice,
    this.busy = false,
    this.completedStars,
    this.newBadgeIds = const {},
    this.error,
  });

  final Chapter chapter;

  /// The simulation as of the current beat.
  final StoryState state;
  final int revision;

  /// A replay of a finished chapter: nothing here changes the saved story.
  final bool practice;

  /// True while a write is in flight; blocks double submissions.
  final bool busy;

  /// Set once the chapter is finished.
  final int? completedStars;
  final Set<String> newBadgeIds;
  final StoryError? error;

  Beat? get beat =>
      state.beat < chapter.beats.length ? chapter.beats[state.beat] : null;

  bool get isComplete => completedStars != null;

  double get progress =>
      chapter.beats.isEmpty ? 1 : state.beat / chapter.beats.length;

  StoryPlay copyWith({
    StoryState? state,
    int? revision,
    bool? busy,
    int? completedStars,
    Set<String>? newBadgeIds,
    StoryError? error,
    bool clearError = false,
  }) => StoryPlay(
    chapter: chapter,
    state: state ?? this.state,
    revision: revision ?? this.revision,
    practice: practice,
    busy: busy ?? this.busy,
    completedStars: completedStars ?? this.completedStars,
    newBadgeIds: newBadgeIds ?? this.newBadgeIds,
    error: clearError ? null : error ?? this.error,
  );
}

final storyControllerProvider = NotifierProvider<StoryController, StoryPlay?>(
  StoryController.new,
);

/// Runs one chapter: applies each beat's outcome with the pure rules and
/// saves a checkpoint after every beat.
class StoryController extends Notifier<StoryPlay?> {
  @override
  StoryPlay? build() {
    // A different player must never continue someone else's story.
    ref.watch(activeProfileIdProvider);
    return null;
  }

  StoryRepository get _repo => ref.read(storyRepositoryProvider);

  int get _profileId {
    final id = ref.read(activeProfileIdProvider);
    if (id == null) throw StateError('No active profile');
    return id;
  }

  /// Opens [number]: continues the story if that is the current chapter, or
  /// starts a practice replay of a finished one. Returns false when the
  /// chapter is still locked or the save cannot be read.
  Future<bool> open(int number) async {
    state = null;
    final StorySave save;
    try {
      save = await _repo.load(_profileId);
    } on Object {
      return false;
    }
    if (!ref.mounted) return false;
    final chapter = chapterByNumber(number);
    final current = save.state;
    if (!current.finished && current.chapter == number) {
      state = StoryPlay(
        chapter: chapter,
        state: current.copyWith(beat: chapter.nextBeat(current, current.beat)),
        revision: save.revision,
        practice: false,
      );
      return true;
    }
    if (number > current.chapter) return false;
    final start =
        save.starts[number] ??
        StoryRules.startChapter(const StoryState(), number);
    state = StoryPlay(
      chapter: chapter,
      state: start.copyWith(beat: chapter.nextBeat(start, 0)),
      revision: save.revision,
      practice: true,
    );
    return true;
  }

  /// Moves past the dialogue or lesson at beat index [at]. A tap that
  /// arrives after the story has already moved on is ignored.
  Future<void> advance(int at) async {
    final current = state;
    if (current == null || current.state.beat != at) return;
    final beat = current.beat;
    if (beat is! Talk && beat is! Teach) return;
    await _step((s) => s);
  }

  /// Applies the outcome of the interactive beat [id]. Ignored unless [id]
  /// is the current beat, so a repeated or late tap can never apply an
  /// outcome twice.
  Future<void> complete(String id, Map<String, Object?> result) async {
    final beat = state?.beat;
    final currentId = switch (beat) {
      Play() => beat.id,
      Pick() => beat.id,
      _ => null,
    };
    if (currentId != id) return;
    await _step((s) => StoryRules.apply(s, id, result));
  }

  Future<void> _step(StoryState Function(StoryState) change) async {
    final current = state;
    if (current == null || current.busy || current.isComplete) return;
    final StoryState next;
    try {
      final changed = change(current.state);
      next = changed.copyWith(
        beat: current.chapter.nextBeat(changed, current.state.beat + 1),
      );
    } on StoryRuleError {
      state = current.copyWith(error: StoryError.invalid);
      return;
    }
    if (current.practice) {
      state = current.copyWith(state: next, clearError: true);
      return;
    }
    state = current.copyWith(busy: true, clearError: true);
    try {
      final revision = await _repo.saveStep(_profileId, next, current.revision);
      if (!ref.mounted) return;
      state = current.copyWith(
        state: next,
        revision: revision,
        busy: false,
        clearError: true,
      );
      ref.invalidate(storySaveProvider);
      ref.invalidate(syncStatusProvider);
    } on StaleStoryException {
      await _reload(current);
    } on Object {
      if (!ref.mounted) return;
      state = current.copyWith(busy: false, error: StoryError.saveFailed);
    }
  }

  /// Finishes the chapter from its summary beat.
  Future<void> finish() async {
    final current = state;
    if (current == null || current.busy || current.isComplete) return;
    if (current.beat is! Recap) return;
    final stars = current.state.stars;
    state = current.copyWith(busy: true, clearError: true);
    try {
      final badges = ref.read(contentProvider).badges;
      final saved = await _repo.completeChapter(
        profileId: _profileId,
        chapter: current.chapter.number,
        stars: stars,
        revision: current.revision,
        next: current.practice ? null : StoryRules.finishChapter(current.state),
        badgeEvaluator: (completed) => earnedBadgeIds(badges, completed),
      );
      if (!ref.mounted) return;
      state = current.copyWith(
        revision: saved.revision,
        busy: false,
        completedStars: stars,
        newBadgeIds: saved.badges,
        clearError: true,
      );
      ref.invalidate(storySaveProvider);
      ref.invalidate(progressSnapshotProvider);
      // A finished chapter is a good moment to send progress to the NGO
      // (if linked and online). Never awaited: the game does not wait.
      unawaited(ref.read(ngoSyncProvider).sync().catchError((Object _) {}));
      if (!current.practice) {
        // The inbox is a nice-to-have: a failure here must not undo the
        // finished chapter.
        try {
          await ref
              .read(dailyActionsProvider)
              .chapterFinished(
                chapter: current.chapter.number,
                stars: stars,
                badgeIds: saved.badges,
              );
        } on Object catch (e) {
          debugPrint('Inbox write failed: $e');
        }
      }
    } on StaleStoryException {
      await _reload(current);
    } on Object {
      if (!ref.mounted) return;
      state = current.copyWith(busy: false, error: StoryError.saveFailed);
    }
  }

  /// The save moved on without us (an earlier tap already stored this
  /// step): show what was actually saved.
  Future<void> _reload(StoryPlay current) async {
    try {
      final save = await _repo.load(_profileId);
      if (!ref.mounted) return;
      if (save.state.chapter != current.chapter.number) {
        state = current.copyWith(
          busy: false,
          completedStars: save.state.done[current.chapter.number] ?? 1,
        );
        return;
      }
      state = current.copyWith(
        state: save.state,
        revision: save.revision,
        busy: false,
      );
    } on Object {
      if (!ref.mounted) return;
      state = current.copyWith(busy: false, error: StoryError.saveFailed);
    }
  }

  void close() => state = null;
}
