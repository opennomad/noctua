# Noctua — Claude notes

## Running

```bash
mise exec -- flutter run -d linux      # Linux desktop (dev)
mise exec -- flutter run               # Android device
mise exec -- flutter analyze           # must be clean before committing
mise exec -- flutter test              # must be clean before committing
```

## Architecture

```
lib/
  main.dart                  # App entry, NoctuaHome, SettingsOverlay wiring; AlarmService.flushPendingLaunchEvent() called in post-frame callback to show dismiss sheet when app cold-launched by tapping an alarm notification
  config/
    noctua_config.dart       # AlarmConfig, ZoneConfig, AnimationParams, NoctuaConfig
    config_service.dart      # ChangeNotifier; load/save/mutate; setAnimationParamsLive for slider preview
  data/
    city_list.dart           # 115 curated (city, IANA tz_id) pairs
  screens/
    alarm/
      alarm_screen.dart      # Alarm list with toggle switches; fade-in + header
      alarm_edit_sheet.dart  # Add/edit bottom sheet; showTimePicker (MediaQuery alwaysUse24HourFormat override); day-of-week toggles; shortcode autocomplete on label field
    clock/
      clock_screen.dart          # Shows logo.svg watermark; moon toggle (top-left) enables night mode (dim overlay, no seconds/date)
      world_clock_screen.dart  # Searchable city picker; custom UTC offset; reorderable list; edit/add buttons inline with label; optional local-time row
    timer/
      timer_screen.dart
      stopwatch_screen.dart
    settings_panel.dart      # Bottom sheet: animation, params, font, time format, colour mode (dark/light/system), sound pickers, screen enable/reorder; header shows logo.svg + NOCTUA wordmark
    colour_scheme_sheet.dart # Per-screen hue pickers; Dark + Light sections; opened from settings_panel
  services/
    alarm_service.dart       # flutter_local_notifications v21 (Android); Dart Timer scheduler (Linux); dynamic channels per sound URI (both alarm and timer channels use _v2 suffix); requestPermissions() checks areNotificationsEnabled/canScheduleExactNotifications/requestFullScreenIntentPermission; getNotificationAppLaunchDetails() stores pending event in _pending_launch_event; flushPendingLaunchEvent() emits it after event listener is wired up; timer notifications use Importance.max + fullScreenIntent + alarmClock mode + 'timer:' payload prefix to avoid triggering alarm dismiss sheet on tap
    ringtone_service.dart    # RingtoneEntry; list() dispatches to Android MethodChannel or Linux filesystem scan; preview(uri)/stopPreview() — Android Ringtone API, Linux paplay subprocess
    timer_persistence.dart   # TimerSession + TimerSnapshot; save on start/pause/reset/dismiss/expire; restore via deadline_ms on launch
  theme/
    color_schemes.dart       # NoctuaColorScheme; NoctuaSchemeScope InheritedWidget; noctuaText(ctx) + noctuaIsLight(ctx) helpers; schemeByName(name, {light}) + schemeFromHue(hue, {light})
    hue_slider.dart          # Shared HueSlider widget + painter (used by colour_scheme_sheet)
    fonts.dart               # google_fonts wrappers; applyFont(); fontPreviewStyle()
  widgets/
    animated_background.dart # Ticker-based; monotonic _t; 'none' = _SolidPainter; loads bubbles.frag FragmentProgram async
    stack_nav.dart           # Swipe/programmatic nav; crossfade BG + FG; pills overlay at bottom edge (SafeArea + 12 px padding); light-aware pill ink colour
    settings_overlay.dart    # Listener (no gesture arena); fade-in gear icon; 3 s auto-hide; top-right corner with 12 px padding; light-mode-aware icon colour
    animations/
      lava_lamp_painter.dart
      raindrops_painter.dart
      bubbles_painter.dart   # GPU GLSL shader (assets/shaders/bubbles.frag); 3×3 cell neighbourhood lookup eliminates grid-line clipping; fract() seamless vertical loop; smoothstep fade-in/out uses 1-smoothstep(lo,hi,x) not smoothstep(hi,lo,x)
      breath_painter.dart    # 96-point organic blob; 7 incommensurable sine harmonics; breathes 55%→90% of half_min; MaskFilter.blur(normal,22) on fill feathers the boundary; two glow stroke passes; no transparent stop in gradient
assets/
  shaders/
    bubbles.frag             # GLSL fragment shader; uniform u_time is fractional cycle (not radians); 3×3 cell neighbourhood; 1-smoothstep for fade-out
```

## Key conventions

- Flutter 3.41 / Dart 3.11 via `mise`
- `flutter_timezone` detects device IANA timezone at startup; `tz.setLocalLocation()` is called in `main()` so `tz.local` is correct — without this, one-shot alarms fire at the wrong time (UTC offset error)
- snake_case locals (lint rules disabled in analysis_options.yaml)
- `color.withAlpha(int)` — never `.red/.green/.blue` (deprecated); use `.r/.g/.b/.a` (double 0–1) when component access is needed (e.g. passing to FragmentShader)
- Animations use a `Ticker` for monotonically increasing time — no hard reset loops
- `Listener` (not `GestureDetector`) for vertical nav in ColumnPage — stays out of gesture arena
- `Platform.isAndroid` / `Platform.isLinux` guards in AlarmService and RingtoneService
- Android notification channels are keyed by sound URI hash; alarm channels: `noctua_alarm_default_v2` / `noctua_alarm_v2_<base36>`; timer channels: `noctua_timer_default_v2` / `noctua_timer_v2_<base36>`; `_v2` suffix forces recreation when channel properties changed (channels are immutable once created)
- `KeyBindings.quit` (default `'Ctrl+w'`) handled before modal/text-field guard in `_onKey`; `_buildKeyLabel()` prepends `Ctrl+`/`Alt+`/`Shift+` from `HardwareKeyboard.instance.isXxxPressed`; quit calls `exit(0)` on Linux, `SystemNavigator.pop()` on Android; `_isModifierKey()` prevents bare modifier presses from being captured as bindings
- Timer notifications use `Importance.max`, `fullScreenIntent: true`, `AndroidScheduleMode.alarmClock`, and `payload: 'timer:$name'`; `_onForegroundNotifResponse` checks `label.startsWith('timer:')` to cancel notification without emitting `AlarmEvent.tapped` (avoids showing alarm dismiss sheet)
- Linux alarm scheduling uses self-rescheduling Dart Timers (no notification daemon); `_linux_sound_proc` stores the `paplay` handle for cancellation; Linux snooze uses `_linux_snooze_timer` (same pattern)
- `formatTime(h, m, fmt)` top-level helper in `noctua_config.dart` — used by Clock, WorldClock, AlarmScreen, and AlarmEditSheet (display + picker via `MediaQuery.alwaysUse24HourFormat`)
- `NoctuaSchemeScope` InheritedWidget injected by `StackNav._scopedScreen(slot)` — wraps each screen with its resolved scheme; `noctuaText(ctx)` reads text colour (falls back to white in modal sheets)
- `NoctuaConfig.color_mode` ('dark'|'light'|'system'); toggled via `ConfigService.setColorMode()` and the Colour Mode chip row in SettingsPanel
- `NoctuaConfig.show_local_time` (bool, default false) — shows device local time row at top of world clock list; toggled in Settings → World Clock
- `NoctuaConfig.night_mode` (bool, default false) — clock screen moon toggle; overlays dim time on black; persisted across restarts; night_clock screen removed
- Night mode `Container(black)` sits outside `SafeArea` in a parent Stack so it covers the status bar area in landscape
- `timer_screen.dart` `_body()` uses `LayoutBuilder` to compress gaps in landscape (tight = maxHeight < 320): spacer 48→16, bottom pill pad 80→40
- `raindrops_painter.dart`: `stroke_w` and `blur` grow with `ring_t` (thin/sharp at impact, wide/soft at full radius)
- `ScreenSlot.light_scheme` — independent hue for light mode (defaults to `scheme`); set via `ConfigService.setScreenLightScheme()`
- `stack_nav.dart`: `StackNav._effectiveLight(context)` resolves dark/light/system; routes to `slot.light_scheme` vs `slot.scheme`; passes resolved `light` bool to `_bg()` and `_scopedScreen()`
- Modal sheets (alarm_edit, alarm_dismiss, settings_panel) always use white text regardless of colour mode
- `RingtoneService.preview(uri)` / `stopPreview()`: Android calls `preview`/`stopPreview` on `noctua/ringtones` MethodChannel (MainActivity holds `_current_ringtone: Ringtone?`); Linux spawns/kills `paplay` subprocess; `_SettingsPanelState` tracks `_previewing: String?`, calls `stopPreview()` in `dispose()`
- Timer state: `_loadSaved()` calls `_saveSession()` after switching active_id; `_restoreSession()` reconstructs idle `_TState` for active_id if not found in snapshots; `_addSaved()` calls `_loadSaved(saved)` with the returned `SavedTimer` (real id) so new timers activate immediately
- `ConfigService.addSavedTimer()` returns the `SavedTimer` with its assigned id (generated by `_next_timer_id()`); callers must use the returned value, not the input, when activating
- `FontFeature.tabularFigures()` on every numeric `Text` (clock, night clock, world clock, alarm list, timer, stopwatch) — prevents digit-width shifting with proportional fonts
- `ScrollConfiguration(behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false))` suppresses the scrollbar widget entirely in bottom sheets (vs `ScrollbarTheme` which only styles it)
- `flutter_svg` renders `assets/logo.svg`; declared in `pubspec.yaml` under `assets`
- `flutter_timezone ^5.0.2`: `FlutterTimezone.getLocalTimezone()` returns `TimezoneInfo`; use `.identifier` property
- `NoctuaConfig.animation_params_map: Map<String, AnimationParams>` stores params per animation; `paramsFor(anim)` looks up map then falls back to `AnimationParams.defaultsFor(anim)`; `setAnimationParams(anim, params)` / `setAnimationParamsLive(anim, params)` in ConfigService both take the animation name; settings panel reloads slider values when switching animation chip
- `AnimationParams.defaultsFor(animation)`: bubbles → 0.5/0.5/0.3; lava_lamp → 1.0/1.1/1.1; all others → 1.0/1.0/1.0
- GLSL `smoothstep(edge0, edge1, x)` is undefined when edge0 ≥ edge1 — always use `1.0 - smoothstep(lo, hi, x)` for a reversed ramp, never `smoothstep(hi, lo, x)`
- `resolveShortcodes(text)` in `data/emoji_shortcodes.dart` — called on save for both alarm labels and timer preset names; `shortcodes` map (764 entries, public const) used for autocomplete prefix-matching
- Shortcode autocomplete: regex `r':([a-zA-Z0-9_]{2,})$'` matched against `text.substring(0, cursor)` — NOT the full text — so it fires at any cursor position; `_applySuggestion` stitches `before[:match_start] + ':name: ' + text[cursor:]`
- Commit only when `flutter analyze` and `flutter test` both report no issues
