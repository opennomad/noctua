# noctua

![Noctua owl logo](assets/logo.svg)

A beautiful, minimal clock app for Linux desktop and Android.

**Official repository:** [code.opennomad.com/opennomad/noctua](https://code.opennomad.com/opennomad/noctua)

Mirrors: [GitHub](https://github.com/opennomad/noctua) · [Codeberg](https://codeberg.org/opennomad/noctua)

Five individually-coloured screens, animated backgrounds, alarm and timer notifications with configurable sound.

## Screens

Screens are navigable by horizontal swipe, keyboard arrow keys, or the icon pills on the right edge:

| Screen | Description |
|--------|-------------|
| **Clock** | Digital clock with date; moon icon toggles night mode (dim overlay, no seconds/date) |
| **World Clock** | Searchable multi-zone clock; reorderable, custom UTC offset |
| **Alarm** | Alarm list with toggle, label, and repeat-day picker |
| **Timer** | Scroll-drum input; multiple simultaneous timers; saved presets |
| **Stopwatch** | Lap recording; fixed-width layout |

Each screen has its own colour scheme, configurable in Settings.

## Features

- **Animated backgrounds** — Lava Lamp, Raindrops, Bubbles (GLSL fragment shader), Breath (organic morphing blob), or None; single shared ticker drives all backgrounds simultaneously; per-animation parameter defaults
- **Per-screen colour** — full hue picker or named presets (blue / purple / green)
- **Font selection** — Default, Orbitron, Raleway, Oxanium, Mono, Exo 2
- **Time format** — toggle between 24-hour and 12-hour (AM/PM); applies to Clock, World Clock, Alarm list, and the alarm time picker
- **Alarms** — one-shot or recurring by day of week; emoji shortcode labels (`:bell: wake up`, `:fire: gym`); full-screen notification with **Dismiss** and **Snooze 10 min** actions; audio routed through the alarm stream (bypasses DND on Android); Dart Timer-based scheduler on Linux (no notification daemon required); Snooze re-fires via the same scheduler on both platforms
- **Timer notifications** — background-safe: fires via `alarmClock` schedule mode; `fullScreenIntent` opens the app on the lock screen when the timer fires; once the app is in the foreground the timer screen plays a looping alarm ringtone directly via the Ringtone API (no popup) and shows a ✓ done indicator; tapping ✓ stops the sound and resets; running/paused/done state persisted to `noctua_timers.json` and restored on next launch
- **Sound selection** — per-platform ringtone catalogue: Android ringtones enumerated via `RingtoneManager`; Linux plays any `.oga`/`.wav` file from `/usr/share/sounds/freedesktop/stereo`; separate pickers for Alarm Sound and Timer Sound in Settings
- **Saved timer presets** — auto-hiding edge pills (left / right / bottom); new preset activates immediately on save; 764-entry emoji shortcode map with inline autocomplete (type `:te` → chips appear for `:tea:`, `:telescope:`, …); works at any cursor position in the name
- **Keyboard navigation** — arrow keys cycle screens; configurable quit shortcut (default `Ctrl+Q`); bindings are disabled while text fields or modals are focused; quit always works even with a modal open
- **Settings overlay** — gear icon fades in on touch, auto-hides after 3 s; bottom-sheet with animation selector, density/speed/amplitude sliders, font picker, per-screen hue sliders, time format toggle, sound pickers, timer-pill edge, keyboard binding editor
- **Config file** — human-readable JSON; `~/.config/noctua/noctua_config.json` on Linux, app documents directory on Android; `noctua_timers.json` in the same directory stores running timer state
- **Android permissions** — `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, and `USE_FULL_SCREEN_INTENT` requested at first launch; each gated on its own availability check so the user is never re-prompted once granted

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
    clock/
      clock_screen.dart          # moon toggle → night mode (dim overlay, no seconds/date)
      world_clock_screen.dart
    timer/
      timer_screen.dart
      stopwatch_screen.dart
    settings_panel.dart
    colour_scheme_sheet.dart
  services/
    alarm_service.dart       # flutter_local_notifications v21 (Android); Dart Timer scheduler (Linux); _v2 channels keyed by sound URI; runtime permissions (notifications, exact alarms, full-screen intent); cold-launch alarm tap handled via getNotificationAppLaunchDetails() + flushPendingLaunchEvent()
    ringtone_service.dart    # cross-platform sound catalogue; Android RingtoneManager via MethodChannel; Linux filesystem scan
    timer_persistence.dart   # TimerSession / TimerSnapshot; save on transitions; restore deadline_ms → remaining on launch
  theme/
    color_schemes.dart       # schemeByName(); schemeFromHue() for hue:NNN keys
    fonts.dart
    hue_slider.dart
  widgets/
    animated_background.dart # ValueNotifier<double> time; scoped repaints via ValueListenableBuilder
    settings_overlay.dart
    stack_nav.dart           # single Ticker drives all AnimatedBackground instances
    animations/
      lava_lamp_painter.dart
      raindrops_painter.dart
      bubbles_painter.dart   # GLSL fragment shader; rising spheres via FragmentProgram
      breath_painter.dart    # organic morphing blob; 96 boundary points; quadratic Bézier path
assets/
  shaders/
    bubbles.frag             # GLSL fragment shader — 3×3 neighbourhood lookup, seamless vertical loop
test/
  config/
    noctua_config_test.dart  # 98 unit tests: all model classes, migration, per-animation params, edge cases
  data/
    emoji_shortcodes_test.dart  # 22 tests: shortcode resolution, map coverage, position-independent resolve
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `path_provider` | Locate config directory on non-Linux platforms |
| `xdg_directories` | XDG config path on Linux |
| `google_fonts` | Runtime font loading |
| `timezone` | IANA timezone database (DST-correct world clock and alarm scheduling) |
| `flutter_local_notifications` | Alarm and timer notifications; Dismiss/Snooze actions (Android) |
