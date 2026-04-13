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
        id: id ?? this.id,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        label: label ?? this.label,
        enabled: enabled ?? this.enabled,
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
        city: json['city'] as String? ?? 'Unknown',
        tz_id: json['tz_id'] as String? ?? 'UTC',
      );

  Map<String, dynamic> toJson() => {'city': city, 'tz_id': tz_id};
}

/// Parameters shared by all animation types.
/// Unknown keys are ignored so adding new fields stays backwards-compatible.
class AnimationParams {
  /// Playback speed multiplier. 0.5 = half speed, 2.0 = double speed.
  final double speed;

  /// Element count / visual density multiplier.
  final double density;

  /// Size or intensity multiplier (blob radius, wave height, ring scale, etc.).
  final double amplitude;

  const AnimationParams({
    this.speed = 1.0,
    this.density = 1.0,
    this.amplitude = 1.0,
  });

  factory AnimationParams.fromJson(Map<String, dynamic> json) => AnimationParams(
        speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
        density: (json['density'] as num?)?.toDouble() ?? 1.0,
        amplitude: (json['amplitude'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() => {
        'speed': speed,
        'density': density,
        'amplitude': amplitude,
      };

  AnimationParams copyWith({double? speed, double? density, double? amplitude}) =>
      AnimationParams(
        speed: speed ?? this.speed,
        density: density ?? this.density,
        amplitude: amplitude ?? this.amplitude,
      );
}

/// Per-column configuration (one entry per horizontal page).
class ColumnConfig {
  final String scheme; // 'blue' | 'purple' | 'green'

  const ColumnConfig({required this.scheme});

  factory ColumnConfig.fromJson(Map<String, dynamic> json) =>
      ColumnConfig(scheme: json['scheme'] as String? ?? 'blue');

  Map<String, dynamic> toJson() => {'scheme': scheme};

  ColumnConfig copyWith({String? scheme}) =>
      ColumnConfig(scheme: scheme ?? this.scheme);
}

/// Root config object written to noctua_config.json.
class NoctuaConfig {
  /// Ordered: [clock column, alarm column, timer column].
  final List<ColumnConfig> columns;

  /// Animation style applied to all backgrounds.
  /// Supported: 'lava_lamp', 'raindrops', 'wave', 'pulse'.
  final String animation;

  /// Parameters for the active animation.
  final AnimationParams animation_params;

  /// Font family key.  'default' means the system font; other values are
  /// resolved by [applyFont] in lib/theme/fonts.dart.
  final String font;

  /// World clock zone list (shown on the Clock column secondary screen).
  final List<ZoneConfig> world_clocks;

  /// Saved alarms.
  final List<AlarmConfig> alarms;

  const NoctuaConfig({
    required this.columns,
    required this.animation,
    this.animation_params = const AnimationParams(),
    this.font = 'default',
    this.world_clocks = const [
      ZoneConfig(city: 'London',   tz_id: 'Europe/London'),
      ZoneConfig(city: 'Tokyo',    tz_id: 'Asia/Tokyo'),
      ZoneConfig(city: 'New York', tz_id: 'America/New_York'),
    ],
    this.alarms = const [],
  });

  static NoctuaConfig get defaults => const NoctuaConfig(
        columns: [
          ColumnConfig(scheme: 'blue'),
          ColumnConfig(scheme: 'purple'),
          ColumnConfig(scheme: 'green'),
        ],
        animation: 'lava_lamp',
        animation_params: AnimationParams(),
        font: 'default',
      );

  factory NoctuaConfig.fromJson(Map<String, dynamic> json) {
    final raw_columns = json['columns'];
    final parsed_columns = raw_columns is List
        ? raw_columns
            .map((c) => ColumnConfig.fromJson(c as Map<String, dynamic>))
            .toList()
        : NoctuaConfig.defaults.columns;

    return NoctuaConfig(
      columns: parsed_columns,
      animation: json['animation'] as String? ?? 'lava_lamp',
      animation_params: json['animation_params'] is Map
          ? AnimationParams.fromJson(
              json['animation_params'] as Map<String, dynamic>)
          : const AnimationParams(),
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
    );
  }

  Map<String, dynamic> toJson() => {
        'columns': columns.map((c) => c.toJson()).toList(),
        'animation': animation,
        'animation_params': animation_params.toJson(),
        'font': font,
        'world_clocks': world_clocks.map((z) => z.toJson()).toList(),
        'alarms': alarms.map((a) => a.toJson()).toList(),
      };

  NoctuaConfig copyWith({
    List<ColumnConfig>? columns,
    String? animation,
    AnimationParams? animation_params,
    String? font,
    List<ZoneConfig>? world_clocks,
    List<AlarmConfig>? alarms,
  }) =>
      NoctuaConfig(
        columns: columns ?? this.columns,
        animation: animation ?? this.animation,
        animation_params: animation_params ?? this.animation_params,
        font: font ?? this.font,
        world_clocks: world_clocks ?? this.world_clocks,
        alarms: alarms ?? this.alarms,
      );
}
