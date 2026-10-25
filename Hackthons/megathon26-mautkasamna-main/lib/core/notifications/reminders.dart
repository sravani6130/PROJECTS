import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

/// One phone notification to show at [at] (local time).
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;

  @override
  String toString() => 'PlannedReminder($id, $at, $title, $body)';
}

/// Schedules the app's phone notifications. Everything is local: nothing is
/// sent over the network.
abstract class Reminders {
  /// Asks for permission to post notifications (Android 13+). True when
  /// allowed.
  Future<bool> requestPermission();

  /// Cancels every reminder this app scheduled and schedules [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Shows a notification on the phone right away (for news such as a
  /// finished chapter). [id] keeps separate messages from replacing each
  /// other.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  });
}

/// Android notifications through `flutter_local_notifications`. Failures are
/// logged and ignored: a reminder is a nudge, never a reason to crash.
class LocalReminders extends Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;

  /// Long texts expand in the notification shade instead of being cut off.
  static NotificationDetails _details(String body, {required bool news}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          news ? 'progress_news' : 'daily_reminder',
          news ? 'Progress news' : 'Daily reminder',
          channelDescription: news
              ? 'Check-ins, streaks, finished chapters and badges'
              : 'Daily check-in and story reminders',
          icon: 'ic_stat_gullak',
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  /// Ids this app uses for scheduled reminders.
  static const idRange = (first: 100, last: 109);

  Future<bool> _init() => _ready ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_gullak'),
        ),
      )
      .then((ok) => ok ?? false)
      .catchError((Object e) {
        debugPrint('Notifications unavailable: $e');
        return false;
      });

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (e) {
      debugPrint('Notification permission failed: $e');
      return false;
    }
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    if (!await _init()) return;
    try {
      for (var id = idRange.first; id <= idRange.last; id++) {
        await _plugin.cancel(id: id);
      }
      for (final r in reminders) {
        await _plugin.zonedSchedule(
          id: r.id,
          // An absolute instant, so no time-zone database is needed.
          scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
          notificationDetails: _details(r.body, news: false),
          // Inexact needs no special alarm permission; a few minutes late is
          // fine for a daily nudge.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: r.title,
          body: r.body,
        );
      }
    } catch (e) {
      debugPrint('Scheduling reminders failed: $e');
    }
  }

  /// Ids for immediate news start here, clear of the reminder range.
  static const newsIdBase = 1000;

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!await _init()) return;
    try {
      await _plugin.show(
        id: newsIdBase + id,
        title: title,
        body: body,
        notificationDetails: _details(body, news: true),
      );
    } catch (e) {
      debugPrint('Showing a notification failed: $e');
    }
  }
}

final remindersProvider = Provider<Reminders>((ref) => LocalReminders());
