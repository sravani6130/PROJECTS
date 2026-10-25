import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/notifications/reminders.dart';
import '../../profiles/application/app_session_controller.dart';
import '../../story/application/story_controller.dart';
import '../../story/domain/story_script.dart';
import '../data/daily_repository.dart';
import '../domain/daily_rules.dart';
import '../domain/inbox.dart';
import 'reminder_planner.dart';

final dailyRepositoryProvider = Provider(
  (ref) => DailyRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Today's check-in state for the active profile. Invalidate after a
/// check-in, and when the app comes back to the front (the day may have
/// changed).
final dailyStatusProvider = FutureProvider<DailyStatus>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return DailyStatus.empty;
  return ref.watch(dailyRepositoryProvider).status(profileId);
});

final inboxProvider = FutureProvider<List<InboxMessage>>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return const [];
  return ref.watch(dailyRepositoryProvider).inbox(profileId);
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return 0;
  return ref.watch(dailyRepositoryProvider).unreadCount(profileId);
});

final reminderSettingProvider = FutureProvider<ReminderSetting>(
  (ref) => ref.watch(dailyRepositoryProvider).reminderSetting(),
);

/// Keeps the phone's scheduled reminders in step with the player: re-plans
/// whenever the check-in, the story, the language or the setting changes.
/// Watched by the home screen.
final reminderSyncProvider = FutureProvider<void>((ref) async {
  final reminders = ref.read(remindersProvider);
  final setting = await ref.watch(reminderSettingProvider.future);
  final profileId = ref.watch(activeProfileIdProvider);
  final hour = setting.hour;
  if (hour == null || profileId == null) {
    await reminders.replaceAll(const []);
    return;
  }
  final status = await ref.watch(dailyStatusProvider.future);
  final story = (await ref.watch(storySaveProvider.future))?.state;
  final t = ref.watch(stringsProvider);
  final next = story == null || story.finished
      ? null
      : chapterByNumber(story.chapter);
  await reminders.replaceAll(
    planReminders(
      now: ref.read(clockProvider)(),
      hour: hour,
      status: status,
      t: t,
      chaptersDone: story?.done.length ?? 0,
      chapterCount: storyChapters.length,
      nextChapterTitle: next == null ? null : t(next.titleKey),
    ),
  );
});

/// Today's check-in, once it has happened in this run of the app, so the
/// home card can celebrate it. Null until then.
final todayCheckInProvider = NotifierProvider<TodayCheckIn, CheckIn?>(
  TodayCheckIn.new,
);

class TodayCheckIn extends Notifier<CheckIn?> {
  @override
  CheckIn? build() {
    ref.watch(activeProfileIdProvider);
    return null;
  }

  void set(CheckIn value) => state = value;
}

final dailyActionsProvider = Provider(DailyActions.new);

/// Writes for check-ins, the inbox and reminders. Every inbox message is
/// also shown on the phone's notification screen.
class DailyActions {
  DailyActions(this._ref);

  final Ref _ref;
  Future<CheckIn?>? _checkingIn;

  DailyRepository get _repo => _ref.read(dailyRepositoryProvider);
  Reminders get _phone => _ref.read(remindersProvider);

  void _refresh() {
    _ref.invalidate(dailyStatusProvider);
    _ref.invalidate(inboxProvider);
    _ref.invalidate(unreadCountProvider);
  }

  /// Puts [messages] on the phone's notification screen.
  Future<void> _post(Iterable<InboxMessage> messages) async {
    final t = _ref.read(stringsProvider);
    final content = _ref.read(contentProvider);
    final language = _ref.read(languageProvider);
    for (final m in messages) {
      await _phone.showNow(
        id: m.id,
        title: t('app_name'),
        body: inboxText(
          t,
          m,
          badgeName: (id) => content.badgeById(id)?.name.of(language),
        ),
      );
    }
  }

  /// Runs when the app opens (and comes back to the front): claims today's
  /// reward if it hasn't been claimed. Overlapping calls share one run, so
  /// it can never pay twice. Returns null when there was nothing to claim.
  Future<CheckIn?> autoCheckIn() =>
      _checkingIn ??= _autoCheckIn().whenComplete(() => _checkingIn = null);

  Future<CheckIn?> _autoCheckIn() async {
    final profileId = _ref.read(activeProfileIdProvider);
    if (profileId == null) return null;
    // The first time, ask Android once so the check-in news and daily
    // reminders can reach the notification screen. Allowed means reminders
    // start on at the default time; they can be changed in Settings.
    final setting = await _repo.reminderSetting();
    if (!setting.asked) {
      final allowed = await _phone.requestPermission();
      await _repo.setReminderHour(allowed ? ReminderSetting.defaultHour : null);
      _ref.invalidate(reminderSettingProvider);
    }
    final claimed = await _repo.checkIn(profileId);
    if (claimed == null) return null;
    if (_ref.read(activeProfileIdProvider) == profileId) {
      _ref.read(todayCheckInProvider.notifier).set(claimed.result);
    }
    _refresh();
    await _post(claimed.messages);
    return claimed.result;
  }

  /// Records a finished chapter (and any new badges) in the inbox.
  Future<void> chapterFinished({
    required int chapter,
    required int stars,
    required Iterable<String> badgeIds,
  }) async {
    final profileId = _ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    final messages = [
      await _repo.addMessage(profileId, InboxKind.chapterDone, {
        'n': chapter,
        'stars': stars,
      }),
      for (final id in badgeIds)
        await _repo.addMessage(profileId, InboxKind.badge, {'id': id}),
      if (chapter == storyChapters.length)
        await _repo.addMessage(profileId, InboxKind.storyDone),
    ];
    _refresh();
    await _post(messages);
  }

  Future<void> markInboxRead() async {
    final profileId = _ref.read(activeProfileIdProvider);
    if (profileId == null) return;
    await _repo.markAllRead(profileId);
    _ref.invalidate(unreadCountProvider);
  }

  /// Turns daily phone reminders on at [hour], or off with null. Turning
  /// them on asks for permission first; returns false if it was refused (the
  /// setting then stays off).
  Future<bool> setReminderHour(int? hour) async {
    if (hour != null && !await _phone.requestPermission()) {
      await _repo.setReminderHour(null);
      _ref.invalidate(reminderSettingProvider);
      return false;
    }
    await _repo.setReminderHour(hour);
    _ref.invalidate(reminderSettingProvider);
    return true;
  }
}

/// A message in the current language. Chapter titles and badge names are
/// looked up now, so they follow a later language switch.
String inboxText(
  AppStrings t,
  InboxMessage m, {
  required String? Function(String id) badgeName,
}) {
  final params = <String, Object>{...m.params};
  if (m.kind == InboxKind.chapterDone) {
    params['title'] = t('c${m.params['n']}_title');
  }
  if (m.kind == InboxKind.badge) {
    final id = '${m.params['id']}';
    params['name'] = badgeName(id) ?? id;
  }
  return t('inbox_${m.kind.name}', params);
}
