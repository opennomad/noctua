import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/noctua_config.dart';

// ── AlarmEvent ────────────────────────────────────────────────────────────────

enum AlarmEventType { tapped, dismissed, snoozed, navigated }

class AlarmEvent {
  final AlarmEventType type;
  final String label;
  final int notif_id;
  const AlarmEvent._(this.type, this.label, this.notif_id);
  factory AlarmEvent.tapped(String l, int id)    => AlarmEvent._(AlarmEventType.tapped,    l, id);
  factory AlarmEvent.dismissed(String l, int id) => AlarmEvent._(AlarmEventType.dismissed, l, id);
  factory AlarmEvent.snoozed(String l, int id)   => AlarmEvent._(AlarmEventType.snoozed,   l, id);
  factory AlarmEvent.navigated(String l, int id) => AlarmEvent._(AlarmEventType.navigated, l, id);
}

// ── AlarmService ──────────────────────────────────────────────────────────────

class AlarmService {
  AlarmService._();

  // ── channels ─────────────────────────────────────────────────────────────
  // noctua/alarms  : scheduling + ringtone service control (Android)
  // noctua/ringtones: ringtone listing + settings-panel preview

  static const _alarm_ch = MethodChannel('noctua/alarms');

  // flutter_local_notifications — only used for Android permission requests.
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  // ── well-known notification / request IDs ─────────────────────────────────

  static const snooze_nid        = 88888;
  static const _ringing_notif_id = 77777; // AlarmRingtoneService.RINGING_NOTIF_ID

  // Alarm: alarm_id × 10 + slot (0–6 = weekday, 7 = one-shot).
  static int _anid(String alarm_id, int slot) =>
      (int.tryParse(alarm_id) ?? 0) * 10 + slot;

  // Timer: 50000 + timer_id (0 for scratch timer).
  static int _tnid(String timer_id) =>
      50000 + (timer_id == '_scratch' ? 0 : (int.tryParse(timer_id) ?? 0));

  // ── event stream ──────────────────────────────────────────────────────────

  static final _event_ctrl = StreamController<AlarmEvent>.broadcast();
  static Stream<AlarmEvent> get events => _event_ctrl.stream;

  // ── added-minutes stream (emitted when user taps +Xm on timer notification)

  static final _added_minutes_ctrl = StreamController<int>.broadcast();
  static Stream<int> get addedMinutes => _added_minutes_ctrl.stream;

  // ── current sound URIs + alert settings ──────────────────────────────────

  static String _alarm_sound   = '';
  static String _timer_sound   = '';
  static int    _snooze_mins   = 10;
  static int    _add_mins      = 1;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  static bool _countdown_enabled = true;
  static int _countdown_within_hours = 12;

  static Future<void> init({
    String alarm_sound  = '',
    String timer_sound  = '',
    int    snooze_mins  = 10,
    int    add_mins     = 1,
    bool   countdown   = true,
    int    countdown_within_hours = 12,
    List<AlarmConfig> alarms = const [],
  }) async {
    _alarm_sound = alarm_sound;
    _timer_sound = timer_sound;
    _snooze_mins = snooze_mins;
    _add_mins    = add_mins;
    _countdown_enabled = countdown;
    _countdown_within_hours = countdown_within_hours;

    if (Platform.isLinux) {
      _cancelAllLinux();
      for (final alarm in alarms) {
        if (alarm.enabled) _scheduleLinux(alarm);
      }
      return;
    }

    if (!Platform.isAndroid) return;

    // Register handler for native→Flutter pushes (notification button taps
    // received while the app is in foreground trigger onNewIntent → invokeMethod).
    _alarm_ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDismissed':
          _event_ctrl.add(AlarmEvent.dismissed('', 0));
        case 'onSnoozed':
          _event_ctrl.add(AlarmEvent.snoozed('', 0));
        case 'onAddedMinutes':
          final mins = (call.arguments as int?) ?? _add_mins;
          _added_minutes_ctrl.add(mins);
        case 'navigateTo':
          final args = call.arguments as Map<dynamic, dynamic>?;
          final screen = args?['screen'] as String? ?? 'alarm';
          _event_ctrl.add(AlarmEvent.navigated(screen, 0));
      }
    });

    if (_ready) return;

    // Initialise FLN solely for its permission-request helpers.
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
      ),
    );
    _ready = true;

    // Reschedule every enabled alarm on startup — ensures alarms survive
    // app kills and AlarmManager purges after device reboot.
    for (final alarm in alarms) {
      if (alarm.enabled) await _scheduleAndroid(alarm);
    }
  }

  static Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return;

    final notifs_ok = await impl.areNotificationsEnabled() ?? false;
    if (!notifs_ok) await impl.requestNotificationsPermission();

    final exact_ok = await impl.canScheduleExactNotifications() ?? true;
    if (!exact_ok) await impl.requestExactAlarmsPermission();
  }

  static Future<void> updateSounds({
    required String alarm,
    required String timer,
    int snooze_mins = 10,
    int add_mins    = 1,
  }) async {
    _alarm_sound = alarm;
    _timer_sound = timer;
    _snooze_mins = snooze_mins;
    _add_mins    = add_mins;
  }

  static Future<void> setCountdownEnabled(bool enabled, {int within_hours = 12}) async {
    _countdown_enabled = enabled;
    _countdown_within_hours = within_hours;
    if (!enabled) {
      await cancelCountdown();
    }
  }

  static Future<void> cancelCountdown() async {
    if (!Platform.isAndroid) return;
    _upcoming_alarms.clear();
    try {
      await _alarm_ch.invokeMethod<void>('cancelCountdown');
    } catch (_) {}
  }

  /// No-op — retained for call-site compatibility; replaced by [checkRinging].
  static void flushPendingLaunchEvent() {}

  /// Check whether AlarmRingtoneService is currently ringing and, if so, emit
  /// an [AlarmEvent.tapped] so the UI can show the alarm-dismiss sheet.
  /// Also polls for any pending action set by a notification button tap while
  /// the app was not in foreground (cold-start / warm-resume paths).
  /// Call this after the first frame and on every app-resume.
  static Future<void> checkRinging() async {
    if (!Platform.isAndroid) return;
    try {
      // Poll for an action set by AlarmActionReceiver (notification button).
      // Returns e.g. "dismissed", "snoozed", "added_minutes:1", or null.
      final pending = await _alarm_ch.invokeMethod<String?>('getPendingAction');
      if (pending != null && pending.isNotEmpty) {
        if (pending == 'dismissed') {
          _event_ctrl.add(AlarmEvent.dismissed('', 0));
          return;
        }
        if (pending == 'snoozed') {
          _event_ctrl.add(AlarmEvent.snoozed('', 0));
          return;
        }
        if (pending.startsWith('added_minutes:')) {
          final mins = int.tryParse(pending.split(':')[1]) ?? _add_mins;
          _added_minutes_ctrl.add(mins);
          return;
        }
      }

      final info = await _alarm_ch.invokeMethod<Map>('getRingingAlarm');
      if (info == null) return;
      final type = (info['type'] as String?) ?? '';
      final name = (info['name'] as String?) ?? '';
      // Navigate to the right screen first, then show the dismiss sheet.
      // This covers cold-start (no onNewIntent) and timer expiry (no tapped event).
      if (type == 'alarm') {
        _event_ctrl.add(AlarmEvent.navigated('alarm', 0));
        _event_ctrl.add(AlarmEvent.tapped(name, _ringing_notif_id));
      } else if (type == 'timer') {
        _event_ctrl.add(AlarmEvent.navigated('timer', 0));
      }
    } catch (_) {}
  }

  // ── alarm API ─────────────────────────────────────────────────────────────

  /// Cancel all alarm notifications then reschedule every enabled alarm.
  static Future<void> syncAll(List<AlarmConfig> alarms) async {
    if (Platform.isLinux) {
      _cancelAllLinux();
      for (final alarm in alarms) {
        if (alarm.enabled) _scheduleLinux(alarm);
      }
      return;
    }
    if (!Platform.isAndroid) return;
    await _cancelAndroid(snooze_nid);
    for (final alarm in alarms) {
      await _cancelAlarmAndroid(alarm);
    }
    for (final alarm in alarms) {
      if (alarm.enabled) await _scheduleAndroid(alarm);
    }
  }

  static Future<void> schedule(AlarmConfig alarm) async {
    if (Platform.isLinux) { _scheduleLinux(alarm); return; }
    if (!Platform.isAndroid) return;
    await _cancelAlarmAndroid(alarm);
    if (alarm.enabled) await _scheduleAndroid(alarm);
  }

  static Future<void> cancel(AlarmConfig alarm) async {
    if (Platform.isLinux) { _cancelLinux(alarm.id); return; }
    if (!Platform.isAndroid) return;
    await _cancelAlarmAndroid(alarm);
  }

  /// Stop the ringtone service (silences the alarm).
  static Future<void> cancelAlarmNotif(int notif_id) async =>
      stopRingtone();

  static Future<void> scheduleSnooze(String label) async {
    if (Platform.isLinux) {
      _linux_snooze_timer?.cancel();
      final display = label.isEmpty ? 'Alarm' : label;
      _linux_snooze_timer = Timer(Duration(minutes: _snooze_mins), () {
        _linux_snooze_timer = null;
        _playLinuxSound(uri: _alarm_sound);
        _event_ctrl.add(AlarmEvent.tapped(display, 0));
      });
      return;
    }
    if (!Platform.isAndroid) return;
    final at = DateTime.now().add(Duration(minutes: _snooze_mins));
    await _scheduleNative(
      req_code:       snooze_nid,
      epoch_ms:       at.millisecondsSinceEpoch,
      sound_uri:      _alarm_sound,
      name:           label.isEmpty ? 'Alarm' : label,
      type:           'alarm',
      crescendo_secs: 30,
      snooze_mins:    _snooze_mins,
      add_mins:       _add_mins,
    );
  }

  // ── timer API ─────────────────────────────────────────────────────────────

  static Future<void> scheduleTimerEnd(
      String id, Duration remaining, String name) async {
    if (!Platform.isAndroid) return;
    final at = DateTime.now().add(remaining);
    await _scheduleNative(
      req_code:       _tnid(id),
      epoch_ms:       at.millisecondsSinceEpoch,
      sound_uri:      _timer_sound,
      name:           name.isEmpty ? 'Timer done' : name,
      type:           'timer',
      crescendo_secs: 0,
      snooze_mins:    _snooze_mins,
      add_mins:       _add_mins,
    );
  }

  static Future<void> cancelTimerEnd(String id) async {
    if (!Platform.isAndroid) return;
    await _cancelAndroid(_tnid(id));
  }

  /// Play the timer-done alarm sound in-app (foreground expiry path).
  /// On Android: starts AlarmRingtoneService (instant-on, no crescendo).
  /// On Linux: plays via paplay.
  static Future<void> notifyTimerDone(String name) async {
    if (Platform.isAndroid) {
      await _startRingtone(
        sound_uri:      _timer_sound,
        name:           name.isEmpty ? 'Timer done' : name,
        type:           'timer',
        crescendo_secs: 0,
        snooze_mins:    _snooze_mins,
        add_mins:       _add_mins,
        req_code:       0,
      );
    } else if (Platform.isLinux) {
      await _playLinuxSound(uri: _timer_sound);
    }
  }

  static Future<void> cancelTimerDone() async {
    if (Platform.isLinux) { _stopLinuxSound(); return; }
    if (!Platform.isAndroid) return;
    await stopRingtone();
  }

  static Future<void> stopRingtone() async {
    if (!Platform.isAndroid) return;
    try { await _alarm_ch.invokeMethod<void>('stopRingtone'); } catch (_) {}
  }

  /// Returns the current ringing alarm info if an alarm/timer is ringing, else null.
  static Future<Map<String, String>?> getRingingAlarm() async {
    if (!Platform.isAndroid) return null;
    try {
      final info = await _alarm_ch.invokeMethod<Map>('getRingingAlarm');
      if (info == null) return null;
      return {
        'type': (info['type'] as String?) ?? '',
        'name': (info['name'] as String?) ?? '',
      };
    } catch (_) { return null; }
  }

  // ── private Android helpers ───────────────────────────────────────────────

  // Tracks all upcoming alarms within the countdown threshold.
  static final List<Map<String, dynamic>> _upcoming_alarms = [];

  static Future<void> _scheduleNative({
    required int    req_code,
    required int    epoch_ms,
    required String sound_uri,
    required String name,
    required String type,
    required int    crescendo_secs,
    int snooze_mins = 10,
    int add_mins    = 1,
  }) async {
    // For alarm type, also schedule the countdown notification (if enabled
    // and within the configured hours threshold).
    if (type == 'alarm' && _countdown_enabled) {
      final hours_until = (epoch_ms - DateTime.now().millisecondsSinceEpoch) / (1000 * 60 * 60);
      if (hours_until > 0 && hours_until <= _countdown_within_hours) {
        // Add to list of upcoming alarms
        _upcoming_alarms.removeWhere((a) => a['epoch_ms'] == epoch_ms);
        _upcoming_alarms.add({
          'epoch_ms': epoch_ms,
          'name': name,
        });
        // Sort by time
        _upcoming_alarms.sort((a, b) => (a['epoch_ms'] as int).compareTo(b['epoch_ms'] as int));

        try {
          await _alarm_ch.invokeMethod<void>('scheduleCountdown', {
            'alarms': _upcoming_alarms,
          });
        } catch (_) {}
      }
    }

    try {
      await _alarm_ch.invokeMethod<void>('scheduleAlarm', {
        'req_code':       req_code,
        'ms':             epoch_ms,
        'sound_uri':      sound_uri,
        'name':           name,
        'type':           type,
        'crescendo_secs': crescendo_secs,
        'snooze_mins':    snooze_mins,
        'add_mins':       add_mins,
      });
    } catch (_) {}
  }

  static Future<void> _cancelAndroid(int req_code) async {
    try {
      await _alarm_ch.invokeMethod<void>('cancelAlarm', {'req_code': req_code});
    } catch (_) {}
    // When any alarm is cancelled, cancel the countdown; it will be
    // rescheduled by _scheduleNative when the next alarm is scheduled.
    _upcoming_alarms.clear();
    try {
      await _alarm_ch.invokeMethod<void>('cancelCountdown');
    } catch (_) {}
  }

  static Future<void> _startRingtone({
    required String sound_uri,
    required String name,
    required String type,
    required int    crescendo_secs,
    int snooze_mins = 10,
    int add_mins    = 1,
    int req_code    = 0,
  }) async {
    // Cancel countdown notification when alarm fires — let the ringing
    // notification take over instead of showing two.
    _upcoming_alarms.clear();
    try {
      await _alarm_ch.invokeMethod<void>('cancelCountdown');
    } catch (_) {}

    try {
      await _alarm_ch.invokeMethod<void>('startRingtone', {
        'sound_uri':      sound_uri,
        'name':           name,
        'type':           type,
        'crescendo_secs': crescendo_secs,
        'snooze_mins':    snooze_mins,
        'add_mins':       add_mins,
        'req_code':       req_code,
      });
    } catch (_) {}
  }

  static Future<void> _scheduleAndroid(AlarmConfig alarm) async {
    final now     = DateTime.now();
    final title   = alarm.label.isEmpty ? 'Alarm' : alarm.label;
    const crescendo = 30;

    if (alarm.repeat_days.isEmpty) {
      var at = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      await _scheduleNative(
        req_code:       _anid(alarm.id, 7),
        epoch_ms:       at.millisecondsSinceEpoch,
        sound_uri:      _alarm_sound,
        name:           title,
        type:           'alarm',
        crescendo_secs: crescendo,
        snooze_mins:    _snooze_mins,
        add_mins:       _add_mins,
      );
    } else {
      for (final day in alarm.repeat_days) {
        final at = _nextWeekdayOccurrenceLocal(day + 1, alarm.hour, alarm.minute);
        await _scheduleNative(
          req_code:       _anid(alarm.id, day),
          epoch_ms:       at.millisecondsSinceEpoch,
          sound_uri:      _alarm_sound,
          name:           title,
          type:           'alarm',
          crescendo_secs: crescendo,
          snooze_mins:    _snooze_mins,
          add_mins:       _add_mins,
        );
      }
    }
  }

  static Future<void> _cancelAlarmAndroid(AlarmConfig alarm) async {
    for (int slot = 0; slot <= 7; slot++) {
      await _cancelAndroid(_anid(alarm.id, slot));
    }
  }

  // ── Linux alarm timers ────────────────────────────────────────────────────
  //
  // flutter_local_notifications has no Linux backend, so alarms are driven by
  // plain Dart Timers. Repeating alarms reschedule themselves on fire.

  static final Map<String, List<Timer>> _linux_timers = {};
  static Timer? _linux_snooze_timer;

  static void _scheduleLinux(AlarmConfig alarm) {
    _cancelLinux(alarm.id);
    if (!alarm.enabled) return;
    final label = alarm.label.isEmpty ? 'Alarm' : alarm.label;
    if (alarm.repeat_days.isEmpty) {
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
      _linux_timers[alarm.id] = alarm.repeat_days
          .map((day) => _linuxRepeatTimer(
              alarm.id, day + 1, alarm.hour, alarm.minute, label))
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
      if (_linux_timers.containsKey(alarm_id)) {
        final timers = _linux_timers[alarm_id]!;
        final new_t = _linuxRepeatTimer(alarm_id, weekday, hour, minute, label);
        final idx   = timers.indexWhere((t) => !t.isActive);
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

  static DateTime _nextWeekdayOccurrenceLocal(int weekday, int hour, int minute) {
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
