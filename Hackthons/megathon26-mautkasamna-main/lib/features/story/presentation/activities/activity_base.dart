import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/game/characters.dart';
import '../../../../core/game/game_style.dart';
import '../../../../core/game/game_widgets.dart';
import '../../../../core/localization/app_strings.dart';
import '../../domain/story_rules.dart';
import '../../domain/story_state.dart';
import '../story_widgets.dart';

typedef ActivityDone = void Function(Map<String, Object?> result);

/// Base for interactive beats. An activity previews changes locally and
/// reports what the player did through [onDone]; the rules then apply it to
/// the saved story, so the activity never changes balances itself.
abstract class ActivityWidget extends ConsumerStatefulWidget {
  const ActivityWidget({
    super.key,
    required this.s,
    required this.onDone,
    this.busy = false,
  });

  /// The story as it stands when the activity opens.
  final StoryState s;
  final ActivityDone onDone;
  final bool busy;
}

mixin ActivityHelpers<T extends ActivityWidget> on ConsumerState<T> {
  AppStrings get t => ref.watch(stringsProvider);

  /// Story text with the simulation's numbers and [extra] filled in.
  String tx(String key, [Map<String, Object> extra = const {}]) =>
      t(key, {...StoryRules.params(widget.s), ...extra});

  Widget guide(
    String key, {
    String who = 'gullu',
    Mood mood = Mood.neutral,
    Map<String, Object> extra = const {},
  }) => GuideStrip(
    who: who,
    speaker: t('name_$who'),
    text: tx(key, extra),
    mood: mood,
  );

  /// Short wait for "processing" moments; instant under reduced motion.
  Future<void> pause(int milliseconds) async {
    if (!motionEnabled(context)) return;
    await Future<void>.delayed(Duration(milliseconds: milliseconds));
  }

  /// The pinned button that hands the result to the story.
  Widget doneButton(
    String labelKey, {
    required Map<String, Object?> Function()? result,
    Map<String, Object> extra = const {},
    IconData? icon,
  }) => GameButton(
    key: const ValueKey('activity_done'),
    label: tx(labelKey, extra),
    icon: icon,
    busy: widget.busy,
    onPressed: result == null
        ? null
        : () {
            successFeedback();
            widget.onDone(result());
          },
  );
}
