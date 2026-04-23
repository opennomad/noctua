/// Keyboard navigation bindings.
class KeyBindings {
  final bool   enabled;
  final String nav_next;
  final String nav_prev;
  final String quit;

  const KeyBindings({
    this.enabled  = true,
    this.nav_next = 'Arrow Right',
    this.nav_prev = 'Arrow Left',
    this.quit     = 'Ctrl+q',
  });

  factory KeyBindings.fromJson(Map<String, dynamic> j) => KeyBindings(
        enabled:  j['enabled']  as bool?   ?? true,
        // fall back to old nav_right / nav_left keys when migrating config
        nav_next: j['nav_next'] as String? ?? j['nav_right'] as String? ?? 'Arrow Right',
        nav_prev: j['nav_prev'] as String? ?? j['nav_left']  as String? ?? 'Arrow Left',
        quit:     j['quit']     as String? ?? 'Ctrl+q',
      );

  Map<String, dynamic> toJson() => {
        'enabled':  enabled,
        'nav_next': nav_next,
        'nav_prev': nav_prev,
        'quit':     quit,
      };

  KeyBindings copyWith({bool? enabled, String? nav_next, String? nav_prev, String? quit}) =>
      KeyBindings(
        enabled:  enabled  ?? this.enabled,
        nav_next: nav_next ?? this.nav_next,
        nav_prev: nav_prev ?? this.nav_prev,
        quit:     quit     ?? this.quit,
      );
}

/// One entry in the navigation stack.
class ScreenSlot {
  /// One of: 'clock', 'world_clock', 'alarm', 'timer', 'stopwatch'.
  final String id;

  /// Colour-scheme name used in dark mode: 'blue' | 'purple' | 'green' | 'hue:NNN'.
  final String scheme;

  /// Colour-scheme name used in light mode.  Defaults to [scheme] when omitted.
  final String light_scheme;

  /// When false the screen is hidden from the navigation stack.
  final bool enabled;

  const ScreenSlot({
    required this.id,
    required this.scheme,
    String? light_scheme,
    this.enabled = true,
  }) : light_scheme = light_scheme ?? scheme;

  factory ScreenSlot.fromJson(Map<String, dynamic> j) => ScreenSlot(
        id:           j['id']           as String? ?? 'clock',
        scheme:       j['scheme']       as String? ?? 'blue',
        light_scheme: j['light_scheme'] as String?,
        enabled:      j['enabled']      as bool?   ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id':           id,
        'scheme':       scheme,
        'light_scheme': light_scheme,
        'enabled':      enabled,
      };

  ScreenSlot copyWith({String? scheme, String? light_scheme, bool? enabled}) =>
      ScreenSlot(
        id:           id,
        scheme:       scheme       ?? this.scheme,
        light_scheme: light_scheme ?? this.light_scheme,
        enabled:      enabled      ?? this.enabled,
      );
}

/// A named saved timer preset.
class SavedTimer {
  final String id;
  final String name;    // emoji / unicode supported
  final int seconds;    // total duration

  const SavedTimer({required this.id, required this.name, required this.seconds});

  factory SavedTimer.fromJson(Map<String, dynamic> json) => SavedTimer(
        id:      json['id']      as String? ?? '0',
        name:    json['name']    as String? ?? '',
        seconds: (json['seconds'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'seconds': seconds};

  SavedTimer copyWith({String? name, int? seconds}) =>
      SavedTimer(id: id, name: name ?? this.name, seconds: seconds ?? this.seconds);
}

/// A single alarm entry.
class AlarmConfig {
  final String id;           // auto-incrementing integer string
  final int hour;            // 0–23
  final int minute;          // 0–59
  final String label;
  final bool enabled;
  final List<int> repeat_days; // 0=Mon … 6=Sun; empty = fire once

  const AlarmConfig({
    required this.id,
    required this.hour,
    required this.minute,
    this.label = '',
    this.enabled = true,
    this.repeat_days = const [],
  });

  factory AlarmConfig.fromJson(Map<String, dynamic> json) => AlarmConfig(
        id:          json['id']    as String? ?? '0',
        hour:        json['hour']  as int?    ?? 0,
        minute:      json['minute'] as int?   ?? 0,
        label:       json['label'] as String? ?? '',
        enabled:     json['enabled'] as bool? ?? true,
        repeat_days: (json['repeat_days'] as List?)
                ?.map((e) => e as int)
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'label': label,
        'enabled': enabled,
        'repeat_days': repeat_days,
      };

  AlarmConfig copyWith({
    String? id,
    int? hour,
    int? minute,
    String? label,
    bool? enabled,
    List<int>? repeat_days,
  }) =>
      AlarmConfig(
        id:          id          ?? this.id,
        hour:        hour        ?? this.hour,
        minute:      minute      ?? this.minute,
        label:       label       ?? this.label,
        enabled:     enabled     ?? this.enabled,
        repeat_days: repeat_days ?? this.repeat_days,
      );

  String get time_string =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get repeat_label {
    if (repeat_days.isEmpty) return 'Once';
    if (repeat_days.length == 7) return 'Every day';
    final sorted = List<int>.from(repeat_days)..sort();
    if (sorted.join() == '01234') return 'Weekdays';
    if (sorted.join() == '56')   return 'Weekends';
    const n = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return sorted.map((d) => n[d]).join(' ');
  }
}

/// A single world-clock entry.
class ZoneConfig {
  final String city;
  final String tz_id; // IANA timezone ID, e.g. 'America/New_York'

  const ZoneConfig({required this.city, required this.tz_id});

  factory ZoneConfig.fromJson(Map<String, dynamic> json) => ZoneConfig(
        city:  json['city']  as String? ?? 'Unknown',
        tz_id: json['tz_id'] as String? ?? 'UTC',
      );

  Map<String, dynamic> toJson() => {'city': city, 'tz_id': tz_id};
}

/// Parameters shared by all animation types.
class AnimationParams {
  /// Playback speed multiplier. 0.5 = half speed, 2.0 = double speed.
  final double speed;

  /// Element count / visual density multiplier.
  final double density;

  /// Size or intensity multiplier (blob radius, wave height, ring scale, etc.).
  final double amplitude;

  /// Travel direction for the wave animation (0.0–1.0 maps to 0–2π).
  /// 0.0 = rightward, 0.25 = downward, 0.5 = leftward, 0.75 = upward.
  final double direction;

  const AnimationParams({
    this.speed = 1.0,
    this.density = 1.0,
    this.amplitude = 1.0,
    this.direction = 0.25,
  });

  factory AnimationParams.fromJson(Map<String, dynamic> json) => AnimationParams(
        speed:     (json['speed']     as num?)?.toDouble() ?? 1.0,
        density:   (json['density']   as num?)?.toDouble() ?? 1.0,
        amplitude: (json['amplitude'] as num?)?.toDouble() ?? 1.0,
        direction: (json['direction'] as num?)?.toDouble() ?? 0.25,
      );

  Map<String, dynamic> toJson() => {
        'speed':     speed,
        'density':   density,
        'amplitude': amplitude,
        'direction': direction,
      };

  AnimationParams copyWith({
    double? speed,
    double? density,
    double? amplitude,
    double? direction,
  }) =>
      AnimationParams(
        speed:     speed     ?? this.speed,
        density:   density   ?? this.density,
        amplitude: amplitude ?? this.amplitude,
        direction: direction ?? this.direction,
      );

  /// Per-animation defaults used when no saved params exist for that animation.
  static AnimationParams defaultsFor(String animation) => switch (animation) {
    'bubbles'   => const AnimationParams(speed: 0.5, density: 0.5, amplitude: 0.3),
    'lava_lamp' => const AnimationParams(speed: 1.0, density: 1.1, amplitude: 1.1),
    _           => const AnimationParams(),
  };
}

/// Format an hour+minute pair according to [time_format].
/// [time_format] is '24h' (default) or '12h'.
/// [include_seconds] adds ':SS' when true.
String formatTime(int hour, int minute, String time_format,
    {int second = 0, bool include_seconds = false}) {
  final m = minute.toString().padLeft(2, '0');
  final s = second.toString().padLeft(2, '0');
  if (time_format == '12h') {
    final period = hour < 12 ? 'AM' : 'PM';
    final h      = hour % 12 == 0 ? 12 : hour % 12;
    final base   = '$h:$m';
    return include_seconds ? '$base:$s $period' : '$base $period';
  }
  final h    = hour.toString().padLeft(2, '0');
  final base = '$h:$m';
  return include_seconds ? '$base:$s' : base;
}

// Parses animation_params_map from JSON, with migration from the old single
// animation_params key so existing config files keep their saved values.
Map<String, AnimationParams> _parseParamsMap(Map<String, dynamic> json) {
  if (json['animation_params_map'] is Map) {
    return (json['animation_params_map'] as Map).map(
      (k, v) => MapEntry(k as String,
          AnimationParams.fromJson(v as Map<String, dynamic>)),
    );
  }
  // Legacy: single animation_params — store it under the saved animation key.
  if (json['animation_params'] is Map) {
    final anim   = json['animation'] as String? ?? 'lava_lamp';
    final params = AnimationParams.fromJson(
        json['animation_params'] as Map<String, dynamic>);
    return {anim: params};
  }
  return const {};
}

/// Root config object written to noctua_config.json.
class NoctuaConfig {
  /// Ordered list of screens in the navigation stack.
  final List<ScreenSlot> screens;

  /// Animation style applied to all backgrounds.
  final String animation;

  /// Per-animation parameters, keyed by animation name.
  /// Animations absent from the map fall back to [AnimationParams.defaultsFor].
  final Map<String, AnimationParams> animation_params_map;

  /// Font family key.
  final String font;

  /// World clock zone list.
  final List<ZoneConfig> world_clocks;

  /// Saved alarms.
  final List<AlarmConfig> alarms;

  /// Saved timer presets.
  final List<SavedTimer> saved_timers;

  /// Which screen edge the timer pills attach to: 'left', 'right', or 'bottom'.
  final String timer_pill_edge;

  /// Keyboard navigation bindings.
  final KeyBindings key_bindings;

  /// Clock display format: '24h' or '12h'.
  final String time_format;

  /// URI / path of the alarm sound.  Empty = platform default.
  final String alarm_sound;

  /// URI / path of the timer-done sound.  Empty = platform default.
  final String timer_sound;

  /// Colour mode: 'dark' (default) or 'light'.
  final String color_mode;

  /// Whether the world clock screen shows the device's local time at the top.
  final bool show_local_time;

  /// Whether the clock screen is in night mode (dim overlay, no seconds/date).
  final bool night_mode;

  /// How long the snooze notification action delays the next alarm ring (minutes).
  final int alarm_snooze_minutes;

  /// How many minutes the "+Xm" timer notification action adds to the timer.
  final int timer_add_minutes;

  /// Whether to show an ongoing "Alarm in Xh Ym" notification.
  final bool alarm_countdown;

  /// Show countdown notification only when alarm is within this many hours.
  final int alarm_countdown_within_hours;

  const NoctuaConfig({
    required this.screens,
    required this.animation,
    this.animation_params_map = const {},
    this.font = 'default',
    this.world_clocks = const [
      ZoneConfig(city: 'London',   tz_id: 'Europe/London'),
      ZoneConfig(city: 'Tokyo',    tz_id: 'Asia/Tokyo'),
      ZoneConfig(city: 'New York', tz_id: 'America/New_York'),
    ],
    this.alarms        = const [],
    this.saved_timers  = const [],
    this.timer_pill_edge = 'left',
    this.key_bindings  = const KeyBindings(),
    this.time_format   = '24h',
    this.alarm_sound            = '',
    this.timer_sound            = '',
    this.color_mode             = 'dark',
    this.show_local_time        = false,
    this.night_mode             = false,
    this.alarm_snooze_minutes   = 10,
    this.timer_add_minutes      = 1,
    this.alarm_countdown       = true,
    this.alarm_countdown_within_hours = 12,
  });

  static NoctuaConfig get defaults => const NoctuaConfig(
        screens: [
          ScreenSlot(id: 'clock',       scheme: 'blue'),     // 215° blue
          ScreenSlot(id: 'world_clock', scheme: 'hue:190'),  // teal
          ScreenSlot(id: 'alarm',       scheme: 'purple'),   // 275° purple
          ScreenSlot(id: 'timer',       scheme: 'green'),    // 130° green
          ScreenSlot(id: 'stopwatch',   scheme: 'hue:45'),   // amber
        ],
        animation: 'lava_lamp',
        animation_params_map: {},
        font: 'default',
      );

  /// Returns the saved params for [animation], falling back to per-animation
  /// defaults when nothing has been saved for that animation yet.
  AnimationParams paramsFor(String animation) =>
      animation_params_map[animation] ?? AnimationParams.defaultsFor(animation);

  factory NoctuaConfig.fromJson(Map<String, dynamic> json) {
    List<ScreenSlot> parsed_screens;

    if (json['screens'] is List) {
      // Current format — filter out removed 'night_clock' screen.
      parsed_screens = (json['screens'] as List)
          .map((s) => ScreenSlot.fromJson(s as Map<String, dynamic>))
          .where((s) => s.id != 'night_clock')
          .toList();
    } else if (json['columns'] is List) {
      // Migrate from old 3-column format
      final cols = (json['columns'] as List)
          .map((c) => (c as Map<String, dynamic>)['scheme'] as String? ?? 'blue')
          .toList();
      String schemeOf(int i) => i < cols.length ? cols[i] : 'blue';
      parsed_screens = [
        ScreenSlot(id: 'clock',       scheme: schemeOf(0)),
        ScreenSlot(id: 'world_clock', scheme: schemeOf(0)),
        ScreenSlot(id: 'alarm',       scheme: schemeOf(1)),
        ScreenSlot(id: 'timer',       scheme: schemeOf(2)),
        ScreenSlot(id: 'stopwatch',   scheme: schemeOf(2)),
      ];
    } else {
      parsed_screens = NoctuaConfig.defaults.screens;
    }

    return NoctuaConfig(
      screens: parsed_screens,
      animation: json['animation'] as String? ?? 'lava_lamp',
      animation_params_map: _parseParamsMap(json),
      font: json['font'] as String? ?? 'default',
      world_clocks: json['world_clocks'] is List
          ? (json['world_clocks'] as List)
              .map((z) => ZoneConfig.fromJson(z as Map<String, dynamic>))
              .toList()
          : const [],
      alarms: json['alarms'] is List
          ? (json['alarms'] as List)
              .map((a) => AlarmConfig.fromJson(a as Map<String, dynamic>))
              .toList()
          : const [],
      saved_timers: json['saved_timers'] is List
          ? (json['saved_timers'] as List)
              .map((t) => SavedTimer.fromJson(t as Map<String, dynamic>))
              .toList()
          : const [],
      timer_pill_edge: json['timer_pill_edge'] as String? ?? 'left',
      key_bindings: json['key_bindings'] is Map
          ? KeyBindings.fromJson(json['key_bindings'] as Map<String, dynamic>)
          : const KeyBindings(),
      time_format:     json['time_format']     as String? ?? '24h',
      alarm_sound:     json['alarm_sound']     as String? ?? '',
      timer_sound:     json['timer_sound']     as String? ?? '',
      color_mode:            json['color_mode']            as String? ?? 'dark',
      show_local_time:       json['show_local_time']       as bool?   ?? false,
      night_mode:            json['night_mode']            as bool?   ?? false,
      alarm_snooze_minutes:  (json['alarm_snooze_minutes'] as num?)?.toInt() ?? 10,
      timer_add_minutes:     (json['timer_add_minutes']    as num?)?.toInt() ?? 1,
      alarm_countdown:      json['alarm_countdown']       as bool?   ?? true,
      alarm_countdown_within_hours: (json['alarm_countdown_within_hours'] as num?)?.toInt() ?? 12,
    );
  }

  Map<String, dynamic> toJson() => {
        'screens':          screens.map((s) => s.toJson()).toList(),
        'animation':        animation,
        'animation_params_map': animation_params_map.map((k, v) => MapEntry(k, v.toJson())),
        'font':             font,
        'world_clocks':     world_clocks.map((z) => z.toJson()).toList(),
        'alarms':           alarms.map((a) => a.toJson()).toList(),
        'saved_timers':     saved_timers.map((t) => t.toJson()).toList(),
        'timer_pill_edge':  timer_pill_edge,
        'key_bindings':     key_bindings.toJson(),
        'time_format':      time_format,
        'alarm_sound':      alarm_sound,
        'timer_sound':      timer_sound,
        'color_mode':            color_mode,
        'show_local_time':       show_local_time,
        'night_mode':            night_mode,
        'alarm_snooze_minutes':  alarm_snooze_minutes,
        'timer_add_minutes':     timer_add_minutes,
        'alarm_countdown':      alarm_countdown,
        'alarm_countdown_within_hours': alarm_countdown_within_hours,
      };

  NoctuaConfig copyWith({
    List<ScreenSlot>?  screens,
    String?            animation,
    Map<String, AnimationParams>? animation_params_map,
    String?            font,
    List<ZoneConfig>?  world_clocks,
    List<AlarmConfig>? alarms,
    List<SavedTimer>?  saved_timers,
    String?            timer_pill_edge,
    KeyBindings?       key_bindings,
    String?            time_format,
    String?            alarm_sound,
    String?            timer_sound,
    String?            color_mode,
    bool?              show_local_time,
    bool?              night_mode,
    int?               alarm_snooze_minutes,
    int?               timer_add_minutes,
    bool?              alarm_countdown,
    int?               alarm_countdown_within_hours,
  }) =>
      NoctuaConfig(
        screens:               screens               ?? this.screens,
        animation:             animation             ?? this.animation,
        animation_params_map:  animation_params_map  ?? this.animation_params_map,
        font:                  font                  ?? this.font,
        world_clocks:          world_clocks          ?? this.world_clocks,
        alarms:                alarms                ?? this.alarms,
        saved_timers:          saved_timers          ?? this.saved_timers,
        timer_pill_edge:       timer_pill_edge       ?? this.timer_pill_edge,
        key_bindings:          key_bindings          ?? this.key_bindings,
        time_format:           time_format           ?? this.time_format,
        alarm_sound:           alarm_sound           ?? this.alarm_sound,
        timer_sound:           timer_sound           ?? this.timer_sound,
        color_mode:            color_mode            ?? this.color_mode,
        show_local_time:       show_local_time       ?? this.show_local_time,
        night_mode:            night_mode            ?? this.night_mode,
alarm_snooze_minutes:  alarm_snooze_minutes  ?? this.alarm_snooze_minutes,
        timer_add_minutes:     timer_add_minutes     ?? this.timer_add_minutes,
        alarm_countdown:      alarm_countdown      ?? this.alarm_countdown,
        alarm_countdown_within_hours: alarm_countdown_within_hours ?? this.alarm_countdown_within_hours,
      );
}
