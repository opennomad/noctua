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
  final int notif_id; // notification ID to cancel when dismissing in-app
  const AlarmEvent._(this.type, this.label, this.notif_id);
  factory AlarmEvent.tapped(String l, int id)    => AlarmEvent._(AlarmEventType.tapped,    l, id);
  factory AlarmEvent.dismissed(String l, int id) => AlarmEvent._(AlarmEventType.dismissed, l, id);
  factory AlarmEvent.snoozed(String l, int id)   => AlarmEvent._(AlarmEventType.snoozed,   l, id);
}

// ── AlarmService ──────────────────────────────────────────────────────────────

class AlarmService {
  AlarmService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static AlarmEvent? _pending_launch_event;

  // ── channel ID helpers ────────────────────────────────────────────────────
  //
  // Android notification channels are immutable once created.  We encode the
  // sound URI into the channel ID so each distinct sound gets its own channel.
  // Empty uri → 'default'; custom uri → base-36 hash suffix.

  static String _alarmChId(String uri) =>
      uri.isEmpty ? 'noctua_alarm_default_v2'
                  : 'noctua_alarm_v2_${uri.hashCode.toRadixString(36)}';

  static String _timerChId(String uri) =>
      uri.isEmpty ? 'noctua_timer_default_v2'
                  : 'noctua_timer_v2_${uri.hashCode.toRadixString(36)}';

  static final Set<String> _created_channels = {};

  // Current sound URIs — kept in sync via [updateSounds].
  static String _alarm_sound = '';
  static String _timer_sound = '';

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

  /// Call once at startup, and again after the user changes sound settings.
  static Future<void> init({
    String alarm_sound = '',
    String timer_sound = '',
    List<AlarmConfig> alarms = const [],
  }) async {
    _alarm_sound = alarm_sound;
    _timer_sound = timer_sound;
    if (Platform.isLinux) {
      // Restore Dart timers for every enabled alarm on startup.
      _cancelAllLinux();
      for (final alarm in alarms) {
        if (alarm.enabled) _scheduleLinux(alarm);
      }
      return;
    }
    if (!Platform.isAndroid) return;
    if (_ready) {
      // Already initialised — just ensure channels for the current sounds.
      await _ensureAlarmChannel(_alarm_sound);
      await _ensureTimerChannel(_timer_sound);
      return;
    }

    const android_settings = AndroidInitializationSettings('ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android_settings),
      onDidReceiveNotificationResponse: _onForegroundNotifResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotifResponse,
    );

    // Create default channels + the currently selected ones.
    await _ensureAlarmChannel('');
    await _ensureAlarmChannel(_alarm_sound);
    await _ensureTimerChannel('');
    await _ensureTimerChannel(_timer_sound);

    _ready = true;

    // Check if the app was launched by tapping an alarm notification (app was
    // dead when the alarm fired).  Store the event so callers can flush it
    // after their event listener is wired up.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (response != null) {
      final label = response.payload ?? '';
      final id    = response.id ?? 0;
      if (!label.startsWith('timer:')) {
        _pending_launch_event = AlarmEvent.tapped(label, id);
      }
    }

    // Reschedule every enabled alarm on startup — mirrors Linux behaviour.
    // Ensures alarms survive app kills where AlarmManager may have lost them,
    // and recovers from any silent scheduling failure on a previous run.
    for (final alarm in alarms) {
      if (alarm.enabled) await _schedule(alarm);
    }
  }

  /// Request POST_NOTIFICATIONS (Android 13+) and SCHEDULE_EXACT_ALARM
  /// (Android 14+) only when not already granted.  Must be called after the
  /// first frame so the system dialog has a window to attach to.
  /// No-op on non-Android platforms.
  static Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return;

    // POST_NOTIFICATIONS — shows an in-app dialog; only ask once.
    final notifs_ok = await impl.areNotificationsEnabled() ?? false;
    if (!notifs_ok) await impl.requestNotificationsPermission();

    // SCHEDULE_EXACT_ALARM — sends the user to system settings; only ask
    // when the permission is actually missing.
    final exact_ok = await impl.canScheduleExactNotifications() ?? true;
    if (!exact_ok) await impl.requestExactAlarmsPermission();

    // USE_FULL_SCREEN_INTENT — granted by default on install but may be
    // revoked on Android 14+.  Returns true immediately if already granted;
    // opens system settings only if the permission is missing.
    await impl.requestFullScreenIntentPermission();
  }

  /// Emit any alarm event that was stored from the notification that launched
  /// the app.  Call this from the UI after the AlarmService.events listener
  /// has been subscribed — typically in a post-frame callback in initState().
  static void flushPendingLaunchEvent() {
    final event = _pending_launch_event;
    _pending_launch_event = null;
    if (event != null) _event_ctrl.add(event);
  }

  /// Update stored sound URIs and lazily create any missing channels.
  static Future<void> updateSounds(
      {required String alarm, required String timer}) async {
    _alarm_sound = alarm;
    _timer_sound = timer;
    if (!Platform.isAndroid) return;
    await _ensureAlarmChannel(alarm);
    await _ensureTimerChannel(timer);
  }

  static Future<void> _ensureAlarmChannel(String uri) async {
    final id = _alarmChId(uri);
    if (_created_channels.contains(id)) return;
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final sound = uri.isEmpty ? null : UriAndroidNotificationSound(uri);
    await impl?.createNotificationChannel(AndroidNotificationChannel(
      id,
      'Alarms',
      description:          'Noctua alarm notifications',
      importance:           Importance.max,
      playSound:            true,
      enableVibration:      true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound:                sound,
    ));
    _created_channels.add(id);
  }

  static Future<void> _ensureTimerChannel(String uri) async {
    final id = _timerChId(uri);
    if (_created_channels.contains(id)) return;
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final sound = uri.isEmpty ? null : UriAndroidNotificationSound(uri);
    await impl?.createNotificationChannel(AndroidNotificationChannel(
      id,
      'Timers',
      description:          'Noctua timer alerts',
      importance:           Importance.max,
      playSound:            true,
      enableVibration:      true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound:                sound,
    ));
    _created_channels.add(id);
  }

  // ── foreground notification response ─────────────────────────────────────

  static void _onForegroundNotifResponse(NotificationResponse r) {
    final label = r.payload ?? '';
    final id    = r.id ?? 0;
    switch (r.actionId) {
      case 'snooze':
        scheduleSnooze(label);
        _event_ctrl.add(AlarmEvent.snoozed(label, id));
      case 'dismiss':
        _event_ctrl.add(AlarmEvent.dismissed(label, id));
      case 'dismiss_timer':
        // cancelNotification: true on the action already removed the notification;
        // no additional cleanup needed.
        _plugin.cancel(id: id);
      default:
        if (label.startsWith('timer:')) {
          // Timer notification tapped — cancel it; timer screen handles done state.
          _plugin.cancel(id: id);
        } else {
          // Bare alarm tap — show in-app dismiss UI.
          _event_ctrl.add(AlarmEvent.tapped(label, id));
        }
    }
  }

  /// Cancel a specific alarm notification by its notification ID.
  static Future<void> cancelAlarmNotif(int notif_id) async {
    if (Platform.isLinux) {
      _linux_snooze_timer?.cancel();
      _linux_snooze_timer = null;
      _stopLinuxSound();
      return;
    }
    if (!Platform.isAndroid) return;
    await _plugin.cancel(id: notif_id);
  }

  // ── public alarm API ──────────────────────────────────────────────────────

  /// Cancel all alarm notifications then reschedule every enabled alarm.
  /// Deliberately does NOT use cancelAll() so that running timer notifications
  /// are not affected.
  static Future<void> syncAll(List<AlarmConfig> alarms) async {
    if (Platform.isLinux) {
      _cancelAllLinux();
      for (final alarm in alarms) {
        if (alarm.enabled) _scheduleLinux(alarm);
      }
      return;
    }
    if (!Platform.isAndroid) return;
    // Cancel the snooze slot plus every alarm individually.
    await _plugin.cancel(id: snooze_nid);
    for (final alarm in alarms) {
      await _cancelAlarm(alarm);
    }
    for (final alarm in alarms) {
      if (alarm.enabled) await _schedule(alarm);
    }
  }

  /// Schedule (or reschedule) a single alarm.
  static Future<void> schedule(AlarmConfig alarm) async {
    if (Platform.isLinux) { _scheduleLinux(alarm); return; }
    if (!Platform.isAndroid) return;
    await _cancelAlarm(alarm);
    if (alarm.enabled) await _schedule(alarm);
  }

  /// Cancel all notifications for a single alarm.
  static Future<void> cancel(AlarmConfig alarm) async {
    if (Platform.isLinux) { _cancelLinux(alarm.id); return; }
    if (!Platform.isAndroid) return;
    await _cancelAlarm(alarm);
  }

  /// Schedule a snooze notification for 10 minutes from now.
  static Future<void> scheduleSnooze(String label) async {
    if (Platform.isLinux) {
      _linux_snooze_timer?.cancel();
      final display = label.isEmpty ? 'Alarm' : label;
      _linux_snooze_timer = Timer(const Duration(minutes: 10), () {
        _linux_snooze_timer = null;
        _playLinuxSound(uri: _alarm_sound);
        _event_ctrl.add(AlarmEvent.tapped(display, 0));
      });
      return;
    }
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
    final at    = tz.TZDateTime.now(tz.local).add(remaining);
    final title = name.isEmpty ? 'Timer done' : name;
    await _plugin.zonedSchedule(
      id:                  _tnid(id),
      title:               title,
      body:                'Your timer has finished',
      scheduledDate:       at,
      notificationDetails: _timerNotifDetails(),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload:             'timer:$name',
    );
  }

  /// Cancel a pending timer-end background notification.
  static Future<void> cancelTimerEnd(String id) async {
    if (!Platform.isAndroid) return;
    await _plugin.cancel(id: _tnid(id));
  }

  /// Dismiss the timer-done notification (shown by [notifyTimerDone]).
  static Future<void> cancelTimerDone() async {
    if (Platform.isLinux) { _stopLinuxSound(); return; }
    if (!Platform.isAndroid) return;
    await _plugin.cancel(id: _timer_done_nid);
  }

  /// Fire an immediate timer-done alert with sound.
  /// On Android: heads-up notification.  On Linux: system sound.
  static Future<void> notifyTimerDone(String name) async {
    if (Platform.isAndroid) {
      final title = name.isEmpty ? 'Timer done' : name;
      await _plugin.show(
        id:                  _timer_done_nid,
        title:               title,
        body:                'Your timer has finished',
        notificationDetails: _timerNotifDetails(),
        payload:             'timer:$name',
      );
    } else if (Platform.isLinux) {
      await _playLinuxSound(uri: _timer_sound);
    }
  }

  // ── notification detail factories (public so background handler can reuse) ─

  // alarmNotifDetails() is called by the background isolate (no sound arg there
  // — it uses the default channel which is always created during init).
  static NotificationDetails alarmNotifDetails({String sound = ''}) {
    final ch_id = _alarmChId(sound);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        ch_id,
        'Alarms',
        channelDescription:   'Noctua alarm notifications',
        importance:           Importance.max,
        priority:             Priority.max,
        fullScreenIntent:     true,
        category:             AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound: sound.isEmpty ? null : UriAndroidNotificationSound(sound),
        actions: const [
          AndroidNotificationAction(
            'dismiss', 'Dismiss',
            cancelNotification:  true,
            showsUserInterface:  true,
          ),
          AndroidNotificationAction(
            'snooze', 'Snooze 10m',
            cancelNotification: true,
            showsUserInterface: false,
          ),
        ],
      ),
    );
  }

  static NotificationDetails _timerNotifDetails() {
    final ch_id = _timerChId(_timer_sound);
    final sound = _timer_sound;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        ch_id,
        'Timers',
        channelDescription:   'Noctua timer alerts',
        importance:           Importance.max,
        priority:             Priority.max,
        fullScreenIntent:     true,
        category:             AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound:            true,
        enableVibration:      true,
        // ongoing prevents the alarm sound from stopping when the notification
        // shade is pulled down (collapsing the heads-up popup).
        ongoing:    true,
        autoCancel: false,
        sound: sound.isEmpty ? null : UriAndroidNotificationSound(sound),
        actions: const [
          AndroidNotificationAction(
            'dismiss_timer', 'Dismiss',
            cancelNotification: true,
          ),
        ],
      ),
    );
  }

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
        notificationDetails: alarmNotifDetails(sound: _alarm_sound),
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
          notificationDetails:      alarmNotifDetails(sound: _alarm_sound),
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

  // ── Linux alarm timers ────────────────────────────────────────────────────
  //
  // flutter_local_notifications has no Linux backend, so we drive alarms with
  // plain Dart Timers.  Repeating alarms reschedule themselves each time they
  // fire.  All timers are keyed by alarm id so they can be cancelled cleanly.

  static final Map<String, List<Timer>> _linux_timers = {};
  static Timer? _linux_snooze_timer;

  static void _scheduleLinux(AlarmConfig alarm) {
    _cancelLinux(alarm.id);
    if (!alarm.enabled) return;
    final label = alarm.label.isEmpty ? 'Alarm' : alarm.label;
    if (alarm.repeat_days.isEmpty) {
      // One-shot: fire once, then remove.
      final delay = _nextOccurrenceLocal(alarm.hour, alarm.minute)
          .difference(DateTime.now());
      _linux_timers[alarm.id] = [
        Timer(delay, () {
          _linux_timers.remove(alarm.id);
          _playLinuxSound(uri: _alarm_sound);
          _event_ctrl.add(AlarmEvent.tapped(label, 0));
        }),
      ];
    } else {
      // Repeating: one timer per day-of-week; each reschedules itself.
      _linux_timers[alarm.id] = alarm.repeat_days
          .map((day) => _linuxRepeatTimer(alarm.id, day + 1, alarm.hour,
              alarm.minute, label))
          .toList();
    }
  }

  static Timer _linuxRepeatTimer(
      String alarm_id, int weekday, int hour, int minute, String label) {
    final delay = _nextWeekdayOccurrenceLocal(weekday, hour, minute)
        .difference(DateTime.now());
    return Timer(delay, () {
      _playLinuxSound();
      _event_ctrl.add(AlarmEvent.tapped(label, 0));
      // Reschedule only if the alarm hasn't been cancelled.
      if (_linux_timers.containsKey(alarm_id)) {
        final timers = _linux_timers[alarm_id]!;
        final new_t = _linuxRepeatTimer(alarm_id, weekday, hour, minute, label);
        final idx = timers.indexWhere((t) => !t.isActive);
        if (idx >= 0) { timers[idx] = new_t; } else { timers.add(new_t); }
      }
    });
  }

  static void _cancelLinux(String alarm_id) {
    _linux_timers.remove(alarm_id)?.forEach((t) => t.cancel());
  }

  static void _cancelAllLinux() {
    for (final id in _linux_timers.keys.toList()) {
      _cancelLinux(id);
    }
  }

  static DateTime _nextOccurrenceLocal(int hour, int minute) {
    final now = DateTime.now();
    var t = DateTime(now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  static DateTime _nextWeekdayOccurrenceLocal(
      int weekday, int hour, int minute) {
    // weekday: 1 = Mon … 7 = Sun (Dart DateTime convention).
    // AlarmConfig uses 0 = Mon … 6 = Sun, so callers pass day + 1.
    final now = DateTime.now();
    var t = DateTime(now.year, now.month, now.day, hour, minute);
    while (t.weekday != weekday || !t.isAfter(now)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  // ── Linux sound ───────────────────────────────────────────────────────────

  static Process? _linux_sound_proc;

  static Future<void> _playLinuxSound({String uri = ''}) async {
    // Use the supplied URI, otherwise fall back to configured sounds,
    // then freedesktop defaults.
    final candidates = [
      if (uri.isNotEmpty) uri,
      if (_alarm_sound.isNotEmpty) _alarm_sound,
      '/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga',
      '/usr/share/sounds/freedesktop/stereo/complete.oga',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) {
        _linux_sound_proc = await Process.start('paplay', [path]);
        return;
      }
    }
    stdout.write('\u0007'); // terminal bell fallback
  }

  static void _stopLinuxSound() {
    _linux_sound_proc?.kill();
    _linux_sound_proc = null;
  }
}
