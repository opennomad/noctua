import 'package:flutter_test/flutter_test.dart';
import 'package:noctua/config/noctua_config.dart';

// ── formatTime ───────────────────────────────────────────────────────────────

void main() {
  // ── formatTime ──────────────────────────────────────────────────────────────

  group('formatTime', () {
    group('24h format', () {
      test('pads single-digit hour and minute', () {
        expect(formatTime(7, 5, '24h'), '07:05');
      });

      test('midnight is 00:00', () {
        expect(formatTime(0, 0, '24h'), '00:00');
      });

      test('end of day is 23:59', () {
        expect(formatTime(23, 59, '24h'), '23:59');
      });

      test('noon is 12:00', () {
        expect(formatTime(12, 0, '24h'), '12:00');
      });

      test('two-digit values need no padding', () {
        expect(formatTime(14, 30, '24h'), '14:30');
      });

      test('include_seconds appends :SS', () {
        expect(formatTime(9, 3, '24h', second: 7, include_seconds: true), '09:03:07');
      });

      test('include_seconds false omits seconds', () {
        expect(formatTime(9, 3, '24h', second: 7, include_seconds: false), '09:03');
      });

      test('unknown format falls back to 24h', () {
        expect(formatTime(14, 0, 'bogus'), '14:00');
      });
    });

    group('12h format', () {
      test('midnight is 12:00 AM', () {
        expect(formatTime(0, 0, '12h'), '12:00 AM');
      });

      test('1 AM', () {
        expect(formatTime(1, 0, '12h'), '1:00 AM');
      });

      test('11 AM', () {
        expect(formatTime(11, 59, '12h'), '11:59 AM');
      });

      test('noon is 12:00 PM', () {
        expect(formatTime(12, 0, '12h'), '12:00 PM');
      });

      test('1 PM', () {
        expect(formatTime(13, 0, '12h'), '1:00 PM');
      });

      test('11 PM', () {
        expect(formatTime(23, 59, '12h'), '11:59 PM');
      });

      test('pads single-digit minute', () {
        expect(formatTime(9, 5, '12h'), '9:05 AM');
      });

      test('no leading zero on hour', () {
        expect(formatTime(7, 30, '12h'), '7:30 AM');
      });

      test('include_seconds appends :SS before period', () {
        expect(formatTime(13, 4, '12h', second: 9, include_seconds: true), '1:04:09 PM');
      });

      test('include_seconds false omits seconds', () {
        expect(formatTime(13, 4, '12h', second: 9, include_seconds: false), '1:04 PM');
      });
    });
  });

  // ── KeyBindings ─────────────────────────────────────────────────────────────

  group('KeyBindings', () {
    test('default values', () {
      const kb = KeyBindings();
      expect(kb.enabled,  isTrue);
      expect(kb.nav_next, 'Arrow Right');
      expect(kb.nav_prev, 'Arrow Left');
    });

    test('fromJson / toJson round-trip', () {
      const kb = KeyBindings(enabled: false, nav_next: 'D', nav_prev: 'A');
      final restored = KeyBindings.fromJson(kb.toJson());
      expect(restored.enabled,  false);
      expect(restored.nav_next, 'D');
      expect(restored.nav_prev, 'A');
    });

    test('fromJson migrates legacy nav_right / nav_left keys', () {
      final kb = KeyBindings.fromJson({
        'enabled':   true,
        'nav_right': 'Arrow Right',
        'nav_left':  'Arrow Left',
      });
      expect(kb.nav_next, 'Arrow Right');
      expect(kb.nav_prev, 'Arrow Left');
    });

    test('fromJson: nav_next takes precedence over legacy nav_right', () {
      final kb = KeyBindings.fromJson({
        'enabled':   true,
        'nav_next':  'D',
        'nav_right': 'Arrow Right',
      });
      expect(kb.nav_next, 'D');
    });

    test('fromJson: missing keys fall back to defaults', () {
      final kb = KeyBindings.fromJson({'enabled': true});
      expect(kb.nav_next, 'Arrow Right');
      expect(kb.nav_prev, 'Arrow Left');
    });

    test('copyWith: only specified fields change', () {
      const kb      = KeyBindings();
      final updated = kb.copyWith(enabled: false, nav_next: 'D');
      expect(updated.enabled,  false);
      expect(updated.nav_next, 'D');
      expect(updated.nav_prev, kb.nav_prev); // unchanged
    });
  });

  // ── ScreenSlot ──────────────────────────────────────────────────────────────

  group('ScreenSlot', () {
    test('fromJson / toJson round-trip', () {
      const slot    = ScreenSlot(id: 'alarm', scheme: 'purple', enabled: false);
      final restored = ScreenSlot.fromJson(slot.toJson());
      expect(restored.id,      'alarm');
      expect(restored.scheme,  'purple');
      expect(restored.enabled, false);
    });

    test('fromJson: missing fields fall back to defaults', () {
      final slot = ScreenSlot.fromJson({});
      expect(slot.id,      'clock');
      expect(slot.scheme,  'blue');
      expect(slot.enabled, true);
    });

    test('copyWith: id is immutable', () {
      const slot    = ScreenSlot(id: 'timer', scheme: 'green');
      final updated = slot.copyWith(scheme: 'purple', enabled: false);
      expect(updated.id,      'timer');
      expect(updated.scheme,  'purple');
      expect(updated.enabled, false);
    });
  });

  // ── SavedTimer ──────────────────────────────────────────────────────────────

  group('SavedTimer', () {
    test('fromJson / toJson round-trip', () {
      const t       = SavedTimer(id: '3', name: '🍅 Pomodoro', seconds: 1500);
      final restored = SavedTimer.fromJson(t.toJson());
      expect(restored.id,      '3');
      expect(restored.name,    '🍅 Pomodoro');
      expect(restored.seconds, 1500);
    });

    test('fromJson: missing fields fall back to defaults', () {
      final t = SavedTimer.fromJson({});
      expect(t.id,      '0');
      expect(t.name,    '');
      expect(t.seconds, 0);
    });

    test('fromJson: accepts double for seconds (JSON num coercion)', () {
      final t = SavedTimer.fromJson({'id': '1', 'name': 'x', 'seconds': 90.0});
      expect(t.seconds, 90);
    });

    test('copyWith: id is immutable', () {
      const t       = SavedTimer(id: '5', name: 'old', seconds: 60);
      final updated = t.copyWith(name: 'new', seconds: 120);
      expect(updated.id,      '5');
      expect(updated.name,    'new');
      expect(updated.seconds, 120);
    });
  });

  // ── AlarmConfig ─────────────────────────────────────────────────────────────

  group('AlarmConfig', () {
    test('fromJson / toJson round-trip', () {
      const a = AlarmConfig(
        id:          '2',
        hour:        7,
        minute:      30,
        label:       'Wake up',
        enabled:     true,
        repeat_days: [0, 1, 2, 3, 4],
      );
      final restored = AlarmConfig.fromJson(a.toJson());
      expect(restored.id,          '2');
      expect(restored.hour,        7);
      expect(restored.minute,      30);
      expect(restored.label,       'Wake up');
      expect(restored.enabled,     true);
      expect(restored.repeat_days, [0, 1, 2, 3, 4]);
    });

    test('fromJson: missing fields fall back to defaults', () {
      final a = AlarmConfig.fromJson({});
      expect(a.id,          '0');
      expect(a.hour,        0);
      expect(a.minute,      0);
      expect(a.label,       '');
      expect(a.enabled,     true);
      expect(a.repeat_days, isEmpty);
    });

    test('copyWith: id is immutable, other fields update', () {
      const a       = AlarmConfig(id: '1', hour: 7, minute: 0);
      final updated = a.copyWith(hour: 8, minute: 30, enabled: false);
      expect(updated.id,      '1');
      expect(updated.hour,    8);
      expect(updated.minute,  30);
      expect(updated.enabled, false);
    });

    // ── time_string ──────────────────────────────────────────────────────────

    group('time_string', () {
      test('pads single-digit hour and minute', () {
        expect(const AlarmConfig(id: '1', hour: 7,  minute: 5).time_string,  '07:05');
      });

      test('midnight', () {
        expect(const AlarmConfig(id: '1', hour: 0,  minute: 0).time_string,  '00:00');
      });

      test('end of day', () {
        expect(const AlarmConfig(id: '1', hour: 23, minute: 59).time_string, '23:59');
      });

      test('two-digit values need no padding', () {
        expect(const AlarmConfig(id: '1', hour: 12, minute: 30).time_string, '12:30');
      });
    });

    // ── repeat_label ─────────────────────────────────────────────────────────

    group('repeat_label', () {
      test('empty → Once', () {
        expect(
          const AlarmConfig(id: '1', hour: 7, minute: 0, repeat_days: []).repeat_label,
          'Once',
        );
      });

      test('all 7 days → Every day', () {
        expect(
          const AlarmConfig(
            id: '1', hour: 7, minute: 0,
            repeat_days: [0, 1, 2, 3, 4, 5, 6],
          ).repeat_label,
          'Every day',
        );
      });

      test('Mon–Fri in order → Weekdays', () {
        expect(
          const AlarmConfig(
            id: '1', hour: 7, minute: 0,
            repeat_days: [0, 1, 2, 3, 4],
          ).repeat_label,
          'Weekdays',
        );
      });

      test('Mon–Fri unsorted → still Weekdays', () {
        expect(
          const AlarmConfig(
            id: '1', hour: 7, minute: 0,
            repeat_days: [4, 2, 0, 3, 1],
          ).repeat_label,
          'Weekdays',
        );
      });

      test('Sat + Sun → Weekends', () {
        expect(
          const AlarmConfig(
            id: '1', hour: 7, minute: 0,
            repeat_days: [5, 6],
          ).repeat_label,
          'Weekends',
        );
      });

      test('Sat + Sun unsorted → Weekends', () {
        expect(
          const AlarmConfig(
            id: '1', hour: 7, minute: 0,
            repeat_days: [6, 5],
          ).repeat_label,
          'Weekends',
        );
      });

      test('single day → abbreviated name', () {
        expect(
          const AlarmConfig(
            id: '1', hour: 7, minute: 0,
            repeat_days: [0],
          ).repeat_label,
          'Mo',
        );
        expect(
          const AlarmConfig(
            id: '1', hour: 7, minute: 0,
            repeat_days: [6],
          ).repeat_label,
          'Su',
        );
      });

      test('Mon, Wed, Fri', () {
        expect(
          const AlarmConfig(
            id: '1', hour: 7, minute: 0,
            repeat_days: [0, 2, 4],
          ).repeat_label,
          'Mo We Fr',
        );
      });

      test('unsorted mixed days are sorted in output', () {
        expect(
          const AlarmConfig(
            id: '1', hour: 7, minute: 0,
            repeat_days: [6, 0, 3],
          ).repeat_label,
          'Mo Th Su',
        );
      });

      test('all abbreviations map correctly', () {
        const days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
        for (int i = 0; i < 7; i++) {
          final label = AlarmConfig(
            id: '1', hour: 7, minute: 0,
            repeat_days: [i],
          ).repeat_label;
          expect(label, days[i], reason: 'day index $i');
        }
      });
    });
  });

  // ── AnimationParams ─────────────────────────────────────────────────────────

  group('AnimationParams', () {
    test('default values', () {
      const p = AnimationParams();
      expect(p.speed,     1.0);
      expect(p.density,   1.0);
      expect(p.amplitude, 1.0);
    });

    test('fromJson / toJson round-trip', () {
      const p       = AnimationParams(speed: 0.5, density: 2.0, amplitude: 1.5);
      final restored = AnimationParams.fromJson(p.toJson());
      expect(restored.speed,     0.5);
      expect(restored.density,   2.0);
      expect(restored.amplitude, 1.5);
    });

    test('fromJson: missing fields fall back to 1.0', () {
      final p = AnimationParams.fromJson({});
      expect(p.speed,     1.0);
      expect(p.density,   1.0);
      expect(p.amplitude, 1.0);
    });

    test('fromJson: accepts int values for double fields', () {
      final p = AnimationParams.fromJson(
          {'speed': 2, 'density': 1, 'amplitude': 3});
      expect(p.speed,     2.0);
      expect(p.density,   1.0);
      expect(p.amplitude, 3.0);
    });

    test('copyWith: unspecified fields are preserved', () {
      const p       = AnimationParams();
      final updated = p.copyWith(speed: 2.0);
      expect(updated.speed,     2.0);
      expect(updated.density,   1.0);
      expect(updated.amplitude, 1.0);
    });

    group('defaultsFor', () {
      test('bubbles defaults: speed 0.5, density 0.5, amplitude 0.3', () {
        final p = AnimationParams.defaultsFor('bubbles');
        expect(p.speed,     0.5);
        expect(p.density,   0.5);
        expect(p.amplitude, 0.3);
      });

      test('lava_lamp defaults: speed 1.0, density 1.1, amplitude 1.1', () {
        final p = AnimationParams.defaultsFor('lava_lamp');
        expect(p.speed,     1.0);
        expect(p.density,   1.1);
        expect(p.amplitude, 1.1);
      });

      test('unknown animation falls back to generic defaults', () {
        final p = AnimationParams.defaultsFor('unknown');
        expect(p.speed,     1.0);
        expect(p.density,   1.0);
        expect(p.amplitude, 1.0);
      });

      test('breath and raindrops use generic defaults', () {
        for (final anim in ['breath', 'raindrops', 'none']) {
          final p = AnimationParams.defaultsFor(anim);
          expect(p.speed,     1.0, reason: anim);
          expect(p.density,   1.0, reason: anim);
          expect(p.amplitude, 1.0, reason: anim);
        }
      });
    });
  });

  // ── NoctuaConfig ────────────────────────────────────────────────────────────

  group('NoctuaConfig', () {
    test('defaults contain 5 screens with expected ids', () {
      final cfg = NoctuaConfig.defaults;
      final ids  = cfg.screens.map((s) => s.id).toList();
      expect(ids, [
        'clock', 'world_clock', 'alarm', 'timer', 'stopwatch',
      ]);
    });

    test('defaults have lava_lamp animation and default font', () {
      final cfg = NoctuaConfig.defaults;
      expect(cfg.animation, 'lava_lamp');
      expect(cfg.font,      'default');
    });

    test('fromJson / toJson full round-trip', () {
      final original = NoctuaConfig.defaults;
      final restored  = NoctuaConfig.fromJson(original.toJson());
      expect(restored.screens.length, 5);
      for (int i = 0; i < original.screens.length; i++) {
        expect(restored.screens[i].id,      original.screens[i].id);
        expect(restored.screens[i].scheme,  original.screens[i].scheme);
        expect(restored.screens[i].enabled, original.screens[i].enabled);
      }
      expect(restored.animation,               original.animation);
      expect(restored.font,                    original.font);
      expect(restored.timer_pill_edge,         original.timer_pill_edge);
      expect(restored.key_bindings.nav_next,   original.key_bindings.nav_next);
      expect(restored.time_format,             original.time_format);
      expect(restored.alarm_sound,             original.alarm_sound);
      expect(restored.timer_sound,             original.timer_sound);
    });

    test('toJson contains all required top-level keys', () {
      final json = NoctuaConfig.defaults.toJson();
      expect(json.keys, containsAll([
        'screens', 'animation', 'animation_params_map', 'font',
        'world_clocks', 'alarms', 'saved_timers',
        'timer_pill_edge', 'key_bindings',
        'time_format', 'alarm_sound', 'timer_sound',
        'color_mode', 'show_local_time', 'night_mode',
      ]));
    });

    test('fromJson: unrecognised fields are silently ignored', () {
      final cfg = NoctuaConfig.fromJson({
        'animation': 'wave',
        'unknown_future_field': 42,
      });
      expect(cfg.animation, 'wave');
    });

    test('fromJson: missing animation falls back to lava_lamp', () {
      final cfg = NoctuaConfig.fromJson({});
      expect(cfg.animation, 'lava_lamp');
    });

    // ── migration from old 3-column format ───────────────────────────────────

    group('migration from old columns format', () {
      test('3 columns map to 5 screens with correct schemes', () {
        final cfg = NoctuaConfig.fromJson({
          'columns': [
            {'scheme': 'blue'},
            {'scheme': 'purple'},
            {'scheme': 'green'},
          ],
          'animation': 'lava_lamp',
        });
        expect(cfg.screens.length, 5);
        // First column (index 0) → clock + world_clock
        expect(cfg.screens[0].id,     'clock');
        expect(cfg.screens[0].scheme, 'blue');
        expect(cfg.screens[1].id,     'world_clock');
        expect(cfg.screens[1].scheme, 'blue');
        // Second column (index 1) → alarm
        expect(cfg.screens[2].id,     'alarm');
        expect(cfg.screens[2].scheme, 'purple');
        // Third column (index 2) → timer + stopwatch
        expect(cfg.screens[3].id,     'timer');
        expect(cfg.screens[3].scheme, 'green');
        expect(cfg.screens[4].id,     'stopwatch');
        expect(cfg.screens[4].scheme, 'green');
      });

      test('partial columns list falls back to blue for missing entries', () {
        final cfg = NoctuaConfig.fromJson({
          'columns': [{'scheme': 'purple'}],
          'animation': 'lava_lamp',
        });
        expect(cfg.screens[0].scheme, 'purple'); // provided
        expect(cfg.screens[2].scheme, 'blue');   // fallback for missing column 1
        expect(cfg.screens[3].scheme, 'blue');   // fallback for missing column 2
      });

      test('night_clock entries are filtered out of saved screen lists', () {
        final cfg = NoctuaConfig.fromJson({
          'screens': [
            {'id': 'clock',       'scheme': 'blue',   'enabled': true},
            {'id': 'night_clock', 'scheme': 'hue:5',  'enabled': true},
            {'id': 'alarm',       'scheme': 'purple',  'enabled': true},
          ],
        });
        final ids = cfg.screens.map((s) => s.id).toList();
        expect(ids, isNot(contains('night_clock')));
        expect(ids, containsAll(['clock', 'alarm']));
      });
    });

    test('fromJson: no screens and no columns falls back to defaults', () {
      final cfg = NoctuaConfig.fromJson({'animation': 'none'});
      expect(cfg.screens, hasLength(5));
    });

    // ── time_format / alarm_sound / timer_sound ──────────────────────────────

    group('time_format', () {
      test('default is 24h', () {
        expect(NoctuaConfig.defaults.time_format, '24h');
      });

      test('fromJson reads value', () {
        final cfg = NoctuaConfig.fromJson({'time_format': '12h'});
        expect(cfg.time_format, '12h');
      });

      test('fromJson missing key falls back to 24h', () {
        final cfg = NoctuaConfig.fromJson({});
        expect(cfg.time_format, '24h');
      });

      test('toJson preserves value', () {
        final cfg  = NoctuaConfig.defaults.copyWith(time_format: '12h');
        expect(cfg.toJson()['time_format'], '12h');
      });
    });

    group('alarm_sound', () {
      test('default is empty string', () {
        expect(NoctuaConfig.defaults.alarm_sound, '');
      });

      test('fromJson reads value', () {
        final cfg = NoctuaConfig.fromJson({'alarm_sound': 'content://media/alarm/1'});
        expect(cfg.alarm_sound, 'content://media/alarm/1');
      });

      test('fromJson missing key falls back to empty string', () {
        expect(NoctuaConfig.fromJson({}).alarm_sound, '');
      });

      test('toJson preserves value', () {
        final cfg = NoctuaConfig.defaults.copyWith(alarm_sound: '/usr/share/sounds/test.oga');
        expect(cfg.toJson()['alarm_sound'], '/usr/share/sounds/test.oga');
      });
    });

    group('timer_sound', () {
      test('default is empty string', () {
        expect(NoctuaConfig.defaults.timer_sound, '');
      });

      test('fromJson reads value', () {
        final cfg = NoctuaConfig.fromJson({'timer_sound': 'content://media/alarm/2'});
        expect(cfg.timer_sound, 'content://media/alarm/2');
      });

      test('fromJson missing key falls back to empty string', () {
        expect(NoctuaConfig.fromJson({}).timer_sound, '');
      });

      test('toJson preserves value', () {
        final cfg = NoctuaConfig.defaults.copyWith(timer_sound: '/usr/share/sounds/test.oga');
        expect(cfg.toJson()['timer_sound'], '/usr/share/sounds/test.oga');
      });
    });

    group('show_local_time', () {
      test('default is false', () {
        expect(NoctuaConfig.defaults.show_local_time, false);
      });

      test('fromJson reads value', () {
        expect(NoctuaConfig.fromJson({'show_local_time': true}).show_local_time, true);
      });

      test('fromJson missing key falls back to false', () {
        expect(NoctuaConfig.fromJson({}).show_local_time, false);
      });

      test('toJson preserves value', () {
        final cfg = NoctuaConfig.defaults.copyWith(show_local_time: true);
        expect(cfg.toJson()['show_local_time'], true);
      });

      test('copyWith updates only show_local_time', () {
        final cfg = NoctuaConfig.defaults.copyWith(show_local_time: true);
        expect(cfg.show_local_time, true);
        expect(cfg.animation, NoctuaConfig.defaults.animation); // unchanged
      });
    });

    group('night_mode', () {
      test('default is false', () {
        expect(NoctuaConfig.defaults.night_mode, false);
      });

      test('fromJson reads value', () {
        expect(NoctuaConfig.fromJson({'night_mode': true}).night_mode, true);
      });

      test('fromJson missing key falls back to false', () {
        expect(NoctuaConfig.fromJson({}).night_mode, false);
      });

      test('toJson preserves value', () {
        final cfg = NoctuaConfig.defaults.copyWith(night_mode: true);
        expect(cfg.toJson()['night_mode'], true);
      });

      test('copyWith updates only night_mode', () {
        final cfg = NoctuaConfig.defaults.copyWith(night_mode: true);
        expect(cfg.night_mode, true);
        expect(cfg.animation, NoctuaConfig.defaults.animation); // unchanged
      });
    });

    // ── paramsFor ─────────────────────────────────────────────────────────────

    group('paramsFor', () {
      test('returns animation-specific defaults when map is empty', () {
        final cfg = NoctuaConfig.defaults; // animation_params_map is {}
        final p   = cfg.paramsFor('bubbles');
        expect(p.speed,     0.5);
        expect(p.density,   0.5);
        expect(p.amplitude, 0.3);
      });

      test('returns saved params when present in map', () {
        const saved = AnimationParams(speed: 1.8, density: 0.7, amplitude: 1.2);
        final cfg   = NoctuaConfig.defaults.copyWith(
          animation_params_map: {'breath': saved},
        );
        final p = cfg.paramsFor('breath');
        expect(p.speed,     1.8);
        expect(p.density,   0.7);
        expect(p.amplitude, 1.2);
      });

      test('falls back to defaultsFor when animation not in map', () {
        final cfg = NoctuaConfig.defaults.copyWith(
          animation_params_map: {'breath': const AnimationParams(speed: 2.0)},
        );
        // bubbles not in map → use AnimationParams.defaultsFor('bubbles')
        expect(cfg.paramsFor('bubbles').speed, 0.5);
      });
    });

    // ── animation_params_map round-trip ───────────────────────────────────────

    group('animation_params_map', () {
      test('fromJson / toJson round-trip preserves per-animation params', () {
        final original = NoctuaConfig.defaults.copyWith(
          animation_params_map: {
            'bubbles':   const AnimationParams(speed: 0.5, density: 0.5, amplitude: 0.3),
            'lava_lamp': const AnimationParams(speed: 1.0, density: 1.1, amplitude: 1.1),
          },
        );
        final restored = NoctuaConfig.fromJson(original.toJson());
        expect(restored.paramsFor('bubbles').speed,        0.5);
        expect(restored.paramsFor('bubbles').density,      0.5);
        expect(restored.paramsFor('bubbles').amplitude,    0.3);
        expect(restored.paramsFor('lava_lamp').density,    1.1);
        expect(restored.paramsFor('lava_lamp').amplitude,  1.1);
      });

      test('fromJson migrates legacy animation_params key to current animation', () {
        final cfg = NoctuaConfig.fromJson({
          'animation':        'breath',
          'animation_params': {'speed': 1.5, 'density': 0.8, 'amplitude': 1.2,
                               'direction': 0.25},
        });
        // Legacy value should land under 'breath'.
        expect(cfg.paramsFor('breath').speed,     1.5);
        expect(cfg.paramsFor('breath').density,   0.8);
        expect(cfg.paramsFor('breath').amplitude, 1.2);
      });

      test('fromJson: absent map and absent legacy key yields empty map', () {
        final cfg = NoctuaConfig.fromJson({'animation': 'lava_lamp'});
        // No saved entry → falls back to per-animation default.
        expect(cfg.animation_params_map, isEmpty);
        expect(cfg.paramsFor('lava_lamp').density, 1.1);
      });
    });

    // ── copyWith ─────────────────────────────────────────────────────────────

    test('copyWith: only specified fields change', () {
      final cfg     = NoctuaConfig.defaults;
      final updated = cfg.copyWith(animation: 'breath', font: 'mono');
      expect(updated.animation, 'breath');
      expect(updated.font,      'mono');
      expect(updated.screens,   cfg.screens); // unchanged
    });
  });

  // ── ZoneConfig ──────────────────────────────────────────────────────────────

  group('ZoneConfig', () {
    test('fromJson / toJson round-trip', () {
      const z       = ZoneConfig(city: 'Tokyo', tz_id: 'Asia/Tokyo');
      final restored = ZoneConfig.fromJson(z.toJson());
      expect(restored.city,  'Tokyo');
      expect(restored.tz_id, 'Asia/Tokyo');
    });

    test('fromJson: missing fields fall back to defaults', () {
      final z = ZoneConfig.fromJson({});
      expect(z.city,  'Unknown');
      expect(z.tz_id, 'UTC');
    });
  });
}
