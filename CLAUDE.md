# Noctua — Claude notes

## Running

```bash
mise exec -- flutter run -d linux      # Linux desktop (dev)
mise exec -- flutter run               # Android device
mise exec -- flutter analyze           # must be clean before committing
```

## Architecture

```
lib/
  main.dart                  # App entry, NoctuaHome, SettingsOverlay wiring
  config/
    noctua_config.dart       # AlarmConfig, ZoneConfig, AnimationParams, NoctuaConfig
    config_service.dart      # ChangeNotifier; load/save/mutate; setAnimationParamsLive for slider preview
  data/
    city_list.dart           # 115 curated (city, IANA tz_id) pairs
  screens/
    alarm/
      alarm_screen.dart      # Alarm list with toggle switches
      alarm_edit_sheet.dart  # Add/edit bottom sheet; showTimePicker; day-of-week toggles
      night_clock_screen.dart
    clock/
      clock_screen.dart
      world_clock_screen.dart  # Searchable city picker; custom UTC offset; reorderable list
    timer/
      timer_screen.dart
      stopwatch_screen.dart
    settings_panel.dart      # Bottom sheet: animation, params, font, per-column hue slider
  services/
    alarm_service.dart       # flutter_local_notifications v21; Android-only (Platform.isAndroid guard)
  theme/
    color_schemes.dart       # NoctuaColorScheme; schemeByName() handles 'blue'/'purple'/'green' + 'hue:NNN'
    fonts.dart               # google_fonts wrappers; applyFont(); fontPreviewStyle()
  widgets/
    animated_background.dart # Ticker-based; monotonic _t; 'none' = _SolidPainter
    settings_overlay.dart    # Listener (no gesture arena); fade-in gear icon; 3 s auto-hide
    animations/
      lava_lamp_painter.dart
      raindrops_painter.dart
      wave_painter.dart      # Off-screen sources → sweeping wavefronts; two wake passes
      pulse_painter.dart     # Fade-in/out envelope; two wake passes; centre glow
```

## Key conventions

- Flutter 3.41 / Dart 3.11 via `mise`
- snake_case locals (lint rules disabled in analysis_options.yaml)
- `color.withAlpha(int)` — never `.red/.green/.blue` (deprecated)
- Animations use a `Ticker` for monotonically increasing time — no hard reset loops
- `Listener` (not `GestureDetector`) for vertical nav in ColumnPage — stays out of gesture arena
- `Platform.isAndroid` guard on all AlarmService calls
- Commit only when `flutter analyze` reports no issues
