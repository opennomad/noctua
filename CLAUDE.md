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
      alarm_screen.dart      # Alarm list with toggle switches; fade-in + header
      alarm_edit_sheet.dart  # Add/edit bottom sheet; showTimePicker; day-of-week toggles
    clock/
      clock_screen.dart          # Shows logo.svg watermark; moon toggle (top-left) enables night mode (dim overlay, no seconds/date)
      world_clock_screen.dart  # Searchable city picker; custom UTC offset; reorderable list; edit/add buttons inline with label; optional local-time row
    timer/
      timer_screen.dart
      stopwatch_screen.dart
    settings_panel.dart      # Bottom sheet: animation, params, font, time format, colour mode (dark/light/system), sound pickers, screen enable/reorder; header shows logo.svg + NOCTUA wordmark
    colour_scheme_sheet.dart # Per-screen hue pickers; Dark + Light sections; opened from settings_panel
  services/
    alarm_service.dart       # flutter_local_notifications v21 (Android); Dart Timer scheduler (Linux); dynamic channels per sound URI; requestPermissions() gated on areNotificationsEnabled/canScheduleExactNotifications
    ringtone_service.dart    # RingtoneEntry; list() dispatches to Android MethodChannel or Linux filesystem scan; preview(uri)/stopPreview() — Android Ringtone API, Linux paplay subprocess
    timer_persistence.dart   # TimerSession + TimerSnapshot; save on start/pause/reset/dismiss/expire; restore via deadline_ms on launch
  theme/
    color_schemes.dart       # NoctuaColorScheme; NoctuaSchemeScope InheritedWidget; noctuaText(ctx) + noctuaIsLight(ctx) helpers; schemeByName(name, {light}) + schemeFromHue(hue, {light})
    hue_slider.dart          # Shared HueSlider widget + painter (used by colour_scheme_sheet)
    fonts.dart               # google_fonts wrappers; applyFont(); fontPreviewStyle()
  widgets/
    animated_background.dart # Ticker-based; monotonic _t; 'none' = _SolidPainter
    stack_nav.dart           # Swipe/programmatic nav; crossfade BG + FG; pills overlay at bottom edge (SafeArea + 12 px padding); light-aware pill ink colour
    settings_overlay.dart    # Listener (no gesture arena); fade-in gear icon; 3 s auto-hide; top-right corner with 12 px padding; light-mode-aware icon colour
    animations/
      lava_lamp_painter.dart
      raindrops_painter.dart
      wave_painter.dart      # Off-screen sources → sweeping wavefronts; no MaskFilter.blur (glow via stacked strokes); 3 rings / 4 sources max; off-screen culling
      pulse_painter.dart     # Fade-in/out envelope; two wake passes; centre glow
```

## Key conventions

- Flutter 3.41 / Dart 3.11 via `mise`
- `flutter_timezone` detects device IANA timezone at startup; `tz.setLocalLocation()` is called in `main()` so `tz.local` is correct — without this, one-shot alarms fire at the wrong time (UTC offset error)
- snake_case locals (lint rules disabled in analysis_options.yaml)
- `color.withAlpha(int)` — never `.red/.green/.blue` (deprecated)
- Animations use a `Ticker` for monotonically increasing time — no hard reset loops
- `Listener` (not `GestureDetector`) for vertical nav in ColumnPage — stays out of gesture arena
- `Platform.isAndroid` / `Platform.isLinux` guards in AlarmService and RingtoneService
- Android notification channels are keyed by sound URI hash (`noctua_alarm_<base36>`); new sound → new channel
- Linux alarm scheduling uses self-rescheduling Dart Timers (no notification daemon); `_linux_sound_proc` stores the `paplay` handle for cancellation; Linux snooze uses `_linux_snooze_timer` (same pattern)
- `formatTime(h, m, fmt)` top-level helper in `noctua_config.dart` — used by Clock, NightClock, WorldClock, AlarmScreen
- `NoctuaSchemeScope` InheritedWidget injected by `StackNav._scopedScreen(slot)` — wraps each screen with its resolved scheme; `noctuaText(ctx)` reads text colour (falls back to white in modal sheets)
- `NoctuaConfig.color_mode` ('dark'|'light'|'system'); toggled via `ConfigService.setColorMode()` and the Colour Mode chip row in SettingsPanel
- `NoctuaConfig.show_local_time` (bool, default false) — shows device local time row at top of world clock list; toggled in Settings → World Clock
- `NoctuaConfig.night_mode` (bool, default false) — clock screen moon toggle; overlays dim time on black; persisted across restarts; night_clock screen removed
- Night mode `Container(black)` sits outside `SafeArea` in a parent Stack so it covers the status bar area in landscape
- `timer_screen.dart` `_body()` uses `LayoutBuilder` to compress gaps in landscape (tight = maxHeight < 320): spacer 48→16, bottom pill pad 80→40
- `raindrops_painter.dart`: `stroke_w` and `blur` grow with `ring_t` (thin/sharp at impact, wide/soft at full radius)
- `wave_painter.dart`: `MaskFilter.blur` removed — replaced with `_glow_layers` (3 stacked transparent strokes per ring); rings 5→3, sources capped at 4, off-screen culling via min/max screen distance
- `ScreenSlot.light_scheme` — independent hue for light mode (defaults to `scheme`); set via `ConfigService.setScreenLightScheme()`
- `stack_nav.dart`: `StackNav._effectiveLight(context)` resolves dark/light/system; routes to `slot.light_scheme` vs `slot.scheme`; passes resolved `light` bool to `_bg()` and `_scopedScreen()`
- Modal sheets (alarm_edit, alarm_dismiss, settings_panel) always use white text regardless of colour mode
- `RingtoneService.preview(uri)` / `stopPreview()`: Android calls `preview`/`stopPreview` on `noctua/ringtones` MethodChannel (MainActivity holds `_current_ringtone: Ringtone?`); Linux spawns/kills `paplay` subprocess; `_SettingsPanelState` tracks `_previewing: String?`, calls `stopPreview()` in `dispose()`
- Timer state bug fix: `_loadSaved()` calls `_saveSession()` after switching active_id; `_restoreSession()` reconstructs idle `_TState` for active_id if not found in snapshots
- `FontFeature.tabularFigures()` on every numeric `Text` (clock, night clock, world clock, alarm list, timer, stopwatch) — prevents digit-width shifting with proportional fonts
- `ScrollConfiguration(behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false))` suppresses the scrollbar widget entirely in bottom sheets (vs `ScrollbarTheme` which only styles it)
- `flutter_svg` renders `assets/logo.svg`; declared in `pubspec.yaml` under `assets`
- `flutter_timezone ^5.0.2`: `FlutterTimezone.getLocalTimezone()` returns `TimezoneInfo`; use `.identifier` property
- Commit only when `flutter analyze` reports no issues
