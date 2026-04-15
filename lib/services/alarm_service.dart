import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../config/noctua_config.dart';

// ── background snooze handler ──────────────────────────────────────────────────
//
// Must be a top-level function — flutter_local_notifications runs it in a
// separate isolate when the user taps "Snooze" while the app is backgrounded.

@pragma('vm:entry-point')
void _onBackgroundNotifResponse(NotificationResponse response) async {
  if (response.actionId != 'snooze') return;

  // Each isolate has its own memory; re-initialise what we need.
  tz_data.initializeTimeZones();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
    ),
  );

  final label = response.payload ?? '';
  final at    = tz.TZDateTime.now(tz.UTC).add(const Duration(minutes: 10));

  await plugin.zonedSchedule(
    id:                  AlarmService.snooze_nid,
    title:               label.isEmpty ? 'Alarm' : label,
    body:                'Snoozed — 10 minutes',
    scheduledDate:       at,
    notificationDetails: AlarmService.alarmNotifDetails(),
    androidScheduleMode: AndroidScheduleMode.alarmClock,
    payload:             label,
  );
}

// ── AlarmEvent ────────────────────────────────────────────────────────────────

enum AlarmEventType { tapped, dismissed, snoozed }

class AlarmEvent {
  final AlarmEventType type;
  final String label;
  const AlarmEvent._(this.type, this.label);
  factory AlarmEvent.tapped(String l)    => AlarmEvent._(AlarmEventType.tapped,    l);
  factory AlarmEvent.dismissed(String l) => AlarmEvent._(AlarmEventType.dismissed, l);
  factory AlarmEvent.snoozed(String l)   => AlarmEvent._(AlarmEventType.snoozed,   l);
}

// ── AlarmService ──────────────────────────────────────────────────────────────

class AlarmService {
  AlarmService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  // ── channel IDs ───────────────────────────────────────────────────────────
  static const _alarm_ch_id   = 'noctua_alarms';
  static const _alarm_ch_name = 'Alarms';
  static const _timer_ch_id   = 'noctua_timers';
  static const _timer_ch_name = 'Timers';

  // ── well-known notification IDs ───────────────────────────────────────────
  static const snooze_nid     = 88888; // used by background handler too
  static const _timer_done_nid = 89999;

  // ── notification ID helpers ───────────────────────────────────────────────

  // Alarm: alarm_id × 10 + slot (slots 0–6 = weekdays, 7 = one-shot).
  static int _anid(String alarm_id, int slot) =>
      (int.tryParse(alarm_id) ?? 0) * 10 + slot;

  // Timer background: 50000 + timer_id (0 for scratch timer).
  static int _tnid(String timer_id) =>
      50000 + (timer_id == '_scratch' ? 0 : (int.tryParse(timer_id) ?? 0));

  // ── event stream (alarm notifications → UI) ───────────────────────────────
  static final _event_ctrl = StreamController<AlarmEvent>.broadcast();
  static Stream<AlarmEvent> get events => _event_ctrl.stream;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    if (_ready) return;

    const android_settings = AndroidInitializationSettings('ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android_settings),
      onDidReceiveNotificationResponse: _onForegroundNotifResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotifResponse,
    );

    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Alarm channel — uses alarm audio stream so it bypasses silent/DND.
    await impl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _alarm_ch_id,
        _alarm_ch_name,
        description:          'Noctua alarm notifications',
        importance:           Importance.max,
        playSound:            true,
        enableVibration:      true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    // Timer channel — uses notification audio stream (softer).
    await impl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _timer_ch_id,
        _timer_ch_name,
        description:     'Noctua timer alerts',
        importance:      Importance.high,
        playSound:       true,
        enableVibration: true,
      ),
    );

    _ready = true;
  }

  // ── foreground notification response ─────────────────────────────────────

  static void _onForegroundNotifResponse(NotificationResponse r) {
    final label = r.payload ?? '';
    switch (r.actionId) {
      case 'snooze':
        scheduleSnooze(label);
        _event_ctrl.add(AlarmEvent.snoozed(label));
      case 'dismiss':
        _event_ctrl.add(AlarmEvent.dismissed(label));
      default:
        // Bare notification tap — show in-app dismiss UI.
        _event_ctrl.add(AlarmEvent.tapped(label));
    }
  }

  // ── public alarm API ──────────────────────────────────────────────────────

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
    await _cancelAlarm(alarm);
    if (alarm.enabled) await _schedule(alarm);
  }

  /// Cancel all notifications for a single alarm.
  static Future<void> cancel(AlarmConfig alarm) async {
    if (!Platform.isAndroid) return;
    await _cancelAlarm(alarm);
  }

  /// Schedule a snooze notification for 10 minutes from now.
  static Future<void> scheduleSnooze(String label) async {
    if (!Platform.isAndroid) return;
    final at = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
    await _plugin.zonedSchedule(
      id:                  snooze_nid,
      title:               label.isEmpty ? 'Alarm' : label,
      body:                'Snoozed — 10 minutes',
      scheduledDate:       at,
      notificationDetails: alarmNotifDetails(),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload:             label,
    );
  }

  // ── public timer API ──────────────────────────────────────────────────────

  /// Schedule a background notification to fire when the timer expires.
  /// Call this whenever a timer starts or resumes.
  static Future<void> scheduleTimerEnd(
      String id, Duration remaining, String name) async {
    if (!Platform.isAndroid) return;
    await _plugin.cancel(id: _tnid(id));
    final at = tz.TZDateTime.now(tz.local).add(remaining);
    await _plugin.zonedSchedule(
      id:                  _tnid(id),
      title:               name.isEmpty ? 'Timer done' : name,
      body:                'Your timer has finished',
      scheduledDate:       at,
      notificationDetails: _timerNotifDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancel a pending timer-end background notification.
  static Future<void> cancelTimerEnd(String id) async {
    if (!Platform.isAndroid) return;
    await _plugin.cancel(id: _tnid(id));
  }

  /// Fire an immediate timer-done alert with sound.
  /// On Android: heads-up notification.  On Linux: system sound.
  static Future<void> notifyTimerDone(String name) async {
    if (Platform.isAndroid) {
      await _plugin.show(
        id:                  _timer_done_nid,
        title:               name.isEmpty ? 'Timer done' : name,
        body:                'Your timer has finished',
        notificationDetails: _timerNotifDetails(),
      );
    } else if (Platform.isLinux) {
      _playLinuxSound();
    }
  }

  // ── notification detail factories (public so background handler can reuse) ─

  static NotificationDetails alarmNotifDetails() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _alarm_ch_id,
          _alarm_ch_name,
          channelDescription:   'Noctua alarm notifications',
          importance:           Importance.max,
          priority:             Priority.max,
          fullScreenIntent:     true,
          category:             AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          actions: [
            AndroidNotificationAction(
              'dismiss', 'Dismiss',
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'snooze', 'Snooze 10m',
              cancelNotification: true,
              showsUserInterface: false,
            ),
          ],
        ),
      );

  static NotificationDetails _timerNotifDetails() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _timer_ch_id,
          _timer_ch_name,
          channelDescription: 'Noctua timer alerts',
          importance:         Importance.high,
          priority:           Priority.high,
          playSound:          true,
          enableVibration:    true,
        ),
      );

  // ── internals ─────────────────────────────────────────────────────────────

  static Future<void> _schedule(AlarmConfig alarm) async {
    final now   = tz.TZDateTime.now(tz.local);
    final title = alarm.label.isEmpty ? 'Alarm' : alarm.label;

    if (alarm.repeat_days.isEmpty) {
      var at = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, alarm.hour, alarm.minute);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));

      await _plugin.zonedSchedule(
        id:                  _anid(alarm.id, 7),
        title:               title,
        body:                alarm.time_string,
        scheduledDate:       at,
        notificationDetails: alarmNotifDetails(),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload:             title,
      );
    } else {
      for (final day in alarm.repeat_days) {
        final at = _nextWeekdayTime(now, day + 1, alarm.hour, alarm.minute);
        await _plugin.zonedSchedule(
          id:                       _anid(alarm.id, day),
          title:                    title,
          body:                     alarm.time_string,
          scheduledDate:            at,
          notificationDetails:      alarmNotifDetails(),
          androidScheduleMode:      AndroidScheduleMode.alarmClock,
          matchDateTimeComponents:  DateTimeComponents.dayOfWeekAndTime,
          payload:                  title,
        );
      }
    }
  }

  static Future<void> _cancelAlarm(AlarmConfig alarm) async {
    for (int slot = 0; slot <= 7; slot++) {
      await _plugin.cancel(id: _anid(alarm.id, slot));
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

  // ── Linux sound ───────────────────────────────────────────────────────────

  static void _playLinuxSound() {
    const candidates = [
      '/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga',
      '/usr/share/sounds/freedesktop/stereo/complete.oga',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) {
        Process.run('paplay', [path]).ignore();
        return;
      }
    }
    stdout.write('\u0007'); // terminal bell fallback
  }
}
