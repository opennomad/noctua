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
  main.dart                  # App entry, NoctuaHome with WidgetsBindingObserver; AlarmService.checkRinging() called in post-frame callback and on every AppLifecycleState.resumed to show the alarm-dismiss sheet when raised by AlarmFireReceiver
  config/
    noctua_config.dart       # AlarmConfig, ZoneConfig, AnimationParams, NoctuaConfig
    config_service.dart      # ChangeNotifier; load/save/mutate; setAnimationParamsLive for slider preview
  data/
    city_list.dart           # 115 curated (city, IANA tz_id) pairs
  screens/
    alarm/
      alarm_screen.dart      # Alarm list with toggle switches; "in Xh Ym" countdown display for enabled alarms; fade-in + header
      alarm_edit_sheet.dart  # Add/edit bottom sheet; showTimePicker (MediaQuery alwaysUse24HourFormat override); day-of-week toggles; shortcode autocomplete on label field
    clock/
      clock_screen.dart          # Shows logo.svg watermark; moon toggle (top-left) enables night mode (dim overlay, no seconds/date)
      world_clock_screen.dart  # Searchable city picker; custom UTC offset; reorderable list; edit/add buttons inline with label; optional local-time row
    timer/
      timer_screen.dart
      stopwatch_screen.dart
    settings_panel.dart      # Bottom sheet: animation, params, font, time format, colour mode (dark/light/system), sound pickers, screen enable/reorder, countdown notification settings; header shows logo + NOCTUA + noctua.opennomad.com link; footer has made-by links and Ko-fi/Liberapay
    colour_scheme_sheet.dart # Per-screen hue pickers; Dark + Light sections; opened from settings_panel
  services/
    alarm_service.dart       # Android: AlarmManager.setAlarmClock() via noctua/alarms MethodChannel; flutter_local_notifications retained only for permission requests; flushPendingLaunchEvent() is a no-op (kept for call-site compat); checkRinging() queries AlarmRingtoneService.ringing_type via getRingingAlarm and emits AlarmEvent.tapped for alarms; notifyTimerDone() starts AlarmRingtoneService via startRingtone; stopRingtone() stops it; Linux: Dart Timer scheduler + paplay subprocess; countdown notification scheduling via scheduleCountdown/cancelCountdown
    ringtone_service.dart    # RingtoneEntry; list() dispatches to Android MethodChannel or Linux filesystem scan; preview(uri)/stopPreview() — Android Ringtone API, Linux paplay subprocess; `_SettingsPanelState` tracks `_previewing: String?`, calls `stopPreview()` in `dispose()`
    timer_persistence.dart   # TimerSession + TimerSnapshot; save on start/pause/reset/dismiss/expire; restore via deadline_ms on launch
  theme/
    color_schemes.dart       # NoctuaColorScheme; NoctuaSchemeScope InheritedWidget; noctuaText(ctx) + noctuaIsLight(ctx) helpers; schemeByName(name, {light}) + schemeFromHue(hue, {light})
    hue_slider.dart          # Shared HueSlider widget + painter (used by colour_scheme_sheet)
    fonts.dart               # google_fonts wrappers; applyFont(); fontPreviewStyle()
  widgets/
    animated_background.dart # Ticker-based; monotonic _t; 'none' = _SolidPainter; loads bubbles.frag FragmentProgram async
    stack_nav.dart           # Swipe/programmatic nav; crossfade BG + FG; pills overlay at bottom edge (SafeArea + 12 px padding); light-aware pill ink colour
    settings_overlay.dart    # Listener (not GestureDetector); fade-in gear icon; 3 s auto-hide; top-right corner with 12 px padding; light-mode-aware icon colour
    animations/
      lava_lamp_painter.dart
      raindrops_painter.dart
      bubbles_painter.dart   # GPU GLSL shader (assets/shaders/bubbles.frag); 3×3 cell neighbourhood lookup eliminates grid-line clipping; fract() seamless vertical loop; smoothstep fade-in/out uses 1-smoothstep(lo,hi,x) not smoothstep(hi,lo,x)
      breath_painter.dart    # 96-point organic blob; 7 incommensurable sine harmonics; breathes 55%→90% of half_min; MaskFilter.blur(normal,22) on fill feathers the boundary; two glow stroke passes; no transparent stop in gradient
assets/
  shaders/
    bubbles.frag             # GLSL fragment shader; uniform u_time is fractional cycle (not radians); 3×3 cell neighbourhood; 1-smoothstep for fade-out

## Versioning

Single source of truth: `pubspec.yaml` (`version: X.Y.Z+buildnum`).

- Flutter and Android read it natively (`flutter.versionName` / `flutter.versionCode` in `android/app/build.gradle.kts`)
- `.mise-env.sh` parses it and exports `$VERSION` (strips `+buildnum`) — used by all `mise` release/package tasks
- `site/.eleventy.js` parses it to inject `{{ version }}` into the Eleventy site
- There is no `VERSION` file; do not create one

To release: bump `version:` in `pubspec.yaml`, then run `mise run release:*`.

## Eleventy site (site/)

The Eleventy site lives in `site/`. Open Graph and Twitter cards are injected via `site/_includes/base.njk` — tags use short frontmatter names `image` and `image_alt`, falling back to the app logo.

- `npm run build` to build the Eleventy site
- `npm start` to serve locally
- `npm run publish` to sync to server

## SEO / Open Graph
- `site/_includes/base.njk` includes `og:title`, `og:description`, `og:image`, `og:image:alt`, `twitter:card` tags
- Per-post images use front matter `image` and `image_alt`; fallback to `/assets/logo.svg`
- Built site: `site/_site/index.html`

## Key conventions

- Flutter 3.41 / Dart 3.11 via `mise`
- `flutter_timezone` detects device IANA timezone at startup; `tz.setLocalLocation()` is called in `main()` so `tz.local` is correct — without this, one-shot alarms fire at the wrong time (UTC offset error)
- snake_case locals (lint rules disabled in analysis_options.yaml)
- `color.withAlpha(int)` — never `.red/.green/.blue` (deprecated); use `.r/.g/.b/.a` (double 0–1) when component access is needed (e.g. passing to FragmentShader)
- Animations use a `Ticker` for monotonically increasing time — no hard reset loops
- `Listener` (not `GestureDetector`) for vertical nav in ColumnPage — stays out of gesture arena
- `Platform.isAndroid` / `Platform.isLinux` guards in AlarmService and RingtoneService
- Android alarm stack: `AlarmManager.setAlarmClock()` fires `AlarmFireReceiver`; receiver starts `AlarmRingtoneService` (foreground service, MediaPlayer + crescendo, `USAGE_ALARM`); `AlarmRingtoneService` posts a full-screen `CATEGORY_ALARM` ongoing notification; companion fields `ringing_type`/`ringing_name` are read by Flutter via `getRingingAlarm` MethodChannel call in `checkRinging()`
- Android notification channel for ringing: `noctua_ringing_v1`, `IMPORTANCE_HIGH`, no channel sound (MediaPlayer handles it); `RINGING_NOTIF_ID = 77777`
- `notifyTimerDone()` on Android starts `AlarmRingtoneService` via `startRingtone` MethodChannel (instant-on, no crescendo, `type=timer`); `cancelTimerDone()` calls `stopRingtone`
- Background timer expiry: `scheduleTimerEnd` schedules via `setAlarmClock`; `AlarmFireReceiver` starts `AlarmRingtoneService` + raises `MainActivity`; `_TState.deadline_ms` stores epoch-ms when running; `_checkExpiredOnResume()` compares wall clock on `AppLifecycleState.resumed` to handle timers that expired while Flutter was suspended; `_dismiss()` calls both `cancelTimerDone()` and `cancelTimerEnd(id)`
- `syncAll()` cancels alarm notifications individually (not `cancelAll()`) so running timer notifications are not affected; `AlarmService.cancel(alarm)` must be called before `deleteAlarm()` in alarm_edit_sheet since `syncAll` no longer nukes everything
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
