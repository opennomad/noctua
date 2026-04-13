import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../config/noctua_config.dart';

/// Manages scheduling and cancellation of alarm notifications.
///
/// All methods are static — call [init] once at app startup, then call
/// [syncAll] after any change to the alarm list to keep the Android alarm
/// manager in sync with the config.
class AlarmService {
  AlarmService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channel_id   = 'noctua_alarms';
  static const _channel_name = 'Alarms';

  // Notification ID scheme: alarm integer ID × 10 + slot.
  // Slots 0–6 = repeat day (Mon–Sun); slot 7 = one-shot.
  static int _nid(String alarm_id, int slot) =>
      (int.tryParse(alarm_id) ?? 0) * 10 + slot;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    if (_ready) return;

    const android = AndroidInitializationSettings('ic_launcher');
    await _plugin.initialize(
        settings: const InitializationSettings(android: android));

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channel_id,
            _channel_name,
            description: 'Noctua alarm notifications',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

    _ready = true;
  }

  // ── public API ────────────────────────────────────────────────────────────

  /// Cancel all pending notifications and reschedule every enabled alarm.
  static Future<void> syncAll(List<AlarmConfig> alarms) async {
    if (!Platform.isAndroid) return;
    await _plugin.cancelAll();
    for (final alarm in alarms) {
      if (alarm.enabled) await _schedule(alarm);
    }
  }

  /// Schedule (or reschedule) a single alarm.
  static Future<void> schedule(AlarmConfig alarm) async {
    if (!Platform.isAndroid) return;
    await _cancel(alarm);
    if (alarm.enabled) await _schedule(alarm);
  }

  /// Cancel all notifications for a single alarm.
  static Future<void> cancel(AlarmConfig alarm) async {
    if (!Platform.isAndroid) return;
    await _cancel(alarm);
  }

  // ── internals ────────────────────────────────────────────────────────────

  static Future<void> _schedule(AlarmConfig alarm) async {
    final now = tz.TZDateTime.now(tz.local);

    if (alarm.repeat_days.isEmpty) {
      // One-shot: next occurrence of the specified time.
      var at = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, alarm.hour, alarm.minute);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));

      await _plugin.zonedSchedule(
        id: _nid(alarm.id, 7),
        title: alarm.label.isEmpty ? 'Alarm' : alarm.label,
        body: alarm.time_string,
        scheduledDate: at,
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
    } else {
      // Recurring: one notification per selected weekday.
      for (final day in alarm.repeat_days) {
        // day 0=Mon…6=Sun; DateTime.weekday 1=Mon…7=Sun
        final target_weekday = day + 1;
        final at = _nextWeekdayTime(now, target_weekday, alarm.hour, alarm.minute);

        await _plugin.zonedSchedule(
          id: _nid(alarm.id, day),
          title: alarm.label.isEmpty ? 'Alarm' : alarm.label,
          body: alarm.time_string,
          scheduledDate: at,
          notificationDetails: _details(),
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  static Future<void> _cancel(AlarmConfig alarm) async {
    for (int slot = 0; slot <= 7; slot++) {
      await _plugin.cancel(id: _nid(alarm.id, slot));
    }
  }

  static tz.TZDateTime _nextWeekdayTime(
      tz.TZDateTime from, int weekday, int hour, int minute) {
    var t = tz.TZDateTime(
        tz.local, from.year, from.month, from.day, hour, minute);
    while (t.weekday != weekday || !t.isAfter(from)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  static NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channel_id,
          _channel_name,
          channelDescription: 'Noctua alarm notifications',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        ),
      );
}
