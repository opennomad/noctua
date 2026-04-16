# noctua

![Noctua owl logo](assets/logo.svg)

A Flutter clock app for Linux desktop and Android. Six individually-coloured screens, animated backgrounds, alarm and timer notifications with configurable sound.

## Screens

Six screens navigable by horizontal swipe, keyboard arrow keys, or the icon pills on the right edge:

| Screen | Description |
|--------|-------------|
| **Clock** | Digital clock with date (blue) |
| **World Clock** | Searchable multi-zone clock; reorderable, custom UTC offset (teal) |
| **Alarm** | Alarm list with toggle, label, and repeat-day picker (purple) |
| **Night Clock** | Dimmed full-screen bedside clock (deep red) |
| **Timer** | Scroll-drum input; multiple simultaneous timers; saved presets (green) |
| **Stopwatch** | Lap recording; fixed-width layout (amber) |

Each screen has its own colour scheme. All six are configurable in settings.

## Features

- **Animated backgrounds** — Lava Lamp, Raindrops, Wave, Pulse, or None; single shared ticker drives all backgrounds simultaneously
- **Per-screen colour** — full hue picker or named presets (blue / purple / green)
- **Font selection** — Default, Orbitron, Raleway, Oxanium, Mono, Exo 2
- **Time format** — toggle between 24-hour and 12-hour (AM/PM); applies to Clock, Night Clock, World Clock, and Alarm list
- **Alarms** — one-shot or recurring by day of week; full-screen notification with **Dismiss** and **Snooze 10 min** actions; audio routed through the alarm stream (bypasses DND on Android); Dart Timer-based scheduler on Linux (no notification daemon required)
- **Timer notifications** — background-safe: a `zonedSchedule` notification fires when the timer expires even if the app is backgrounded; in-app ✓ done indicator silences sound and dismisses
- **Sound selection** — per-platform ringtone catalogue: Android ringtones enumerated via `RingtoneManager`; Linux plays any `.oga`/`.wav` file from `/usr/share/sounds/freedesktop/stereo`; separate pickers for Alarm Sound and Timer Sound in Settings
- **Saved timer presets** — auto-hiding edge pills (left / right / bottom); `:shortcode:` emoji syntax in names (`:tea:`, `:pizza:`, etc.)
- **Keyboard navigation** — arrow keys (configurable) cycle screens; disabled while text fields or modals are focused
- **Settings overlay** — gear icon fades in on touch, auto-hides after 3 s; bottom-sheet with animation selector, density/speed/amplitude sliders, font picker, per-screen hue sliders, time format toggle, sound pickers, timer-pill edge, keyboard binding editor
- **Config file** — human-readable JSON; `~/.config/noctua/noctua_config.json` on Linux, app documents directory on Android

## Running

```bash
mise exec -- flutter run -d linux      # Linux desktop (dev)
mise exec -- flutter run               # connected Android device
mise exec -- flutter analyze           # must be clean before committing
mise exec -- flutter test              # run unit tests
```

## Project layout

```
lib/
  main.dart                  # app entry, NoctuaHome, alarm event subscription
  config/
    noctua_config.dart       # AlarmConfig, ZoneConfig, AnimationParams, NoctuaConfig
    config_service.dart      # ChangeNotifier; load/save/mutate config
  data/
    city_list.dart           # 115 curated (city, IANA tz_id) pairs
  screens/
    alarm/
      alarm_screen.dart
      alarm_edit_sheet.dart
      alarm_dismiss_sheet.dart   # Dismiss / Snooze 10 min bottom sheet
      night_clock_screen.dart
    clock/
      clock_screen.dart
      world_clock_screen.dart
    timer/
      timer_screen.dart
      stopwatch_screen.dart
    settings_panel.dart
  services/
    alarm_service.dart       # flutter_local_notifications v21 (Android); Dart Timer scheduler (Linux); dynamic channels keyed by sound URI
    ringtone_service.dart    # cross-platform sound catalogue; Android RingtoneManager via MethodChannel; Linux filesystem scan
  theme/
    color_schemes.dart       # schemeByName(); schemeFromHue() for hue:NNN keys
    fonts.dart
  widgets/
    animated_background.dart # ValueNotifier<double> time; scoped repaints via ValueListenableBuilder
    settings_overlay.dart
    stack_nav.dart           # single Ticker drives all AnimatedBackground instances
    animations/
      lava_lamp_painter.dart
      raindrops_painter.dart
      wave_painter.dart
      pulse_painter.dart
test/
  config/
    noctua_config_test.dart  # 45 unit tests: all model classes, migration, edge cases
  data/
    emoji_shortcodes_test.dart  # 18 tests: shortcode resolution
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `path_provider` | Locate config directory on non-Linux platforms |
| `xdg_directories` | XDG config path on Linux |
| `google_fonts` | Runtime font loading |
| `timezone` | IANA timezone database (DST-correct world clock and alarm scheduling) |
| `flutter_local_notifications` | Alarm and timer notifications; Dismiss/Snooze actions (Android) |
