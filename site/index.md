---
layout: base.njk
title: Noctua — A Clock App for Linux and Android
description: Five individually-coloured screens, animated backgrounds, alarms, timers, and world clock. Runs on Linux desktop and Android.
---

<header class="hero">

![Noctua owl logo](../assets/logo.svg)

# Noctua

**A beautiful, minimal clock app for Linux and Android.**

Five screens. Animated backgrounds. Alarms that fire.

<nav class="cta-row">
  <a class="btn btn-primary" href="https://code.opennomad.com/opennomad/noctua">Official Repo</a>
  <a class="btn btn-secondary" href="#getting-started">Get Started</a>
  <a class="btn btn-secondary" href="https://codeberg.org/opennomad/noctua">Codeberg</a>
  <a class="btn btn-secondary" href="https://github.com/opennomad/noctua">GitHub</a>
</nav>

</header>

---

## Screens

Horizontal swipe, arrow keys, or the icon pills on the right edge.

<div class="screen-grid">

<div class="screen-card">

### Clock

![Clock screen placeholder](img/screen-clock.png)
Digital time and date. Configurable font and colour. Moon icon toggles night mode — dimmed display, no seconds or date.

</div>

<div class="screen-card">

### World Clock

![World Clock screen placeholder](img/screen-world-clock.png)
Search 115 cities or add a custom UTC offset. Drag to reorder. DST-aware.

</div>

<div class="screen-card">

### Alarm

![Alarm screen placeholder](img/screen-alarm.png)
One-shot and repeating alarms. Emoji shortcode labels (`:bell:`, `:fire:`, `:pizza:`). Day-of-week toggles. Dismiss or snooze 10 min.

</div>

<div class="screen-card">

### Timer

![Timer screen placeholder](img/screen-timer.png)
Scroll-drum input. Multiple simultaneous timers. Saved presets with emoji names. State persists across restarts.

</div>

<div class="screen-card">

### Stopwatch

![Stopwatch screen placeholder](img/screen-stopwatch.png)
Lap recording with fixed-width layout.

</div>

<div class="screen-card">

### Settings

![Settings panel](img/screenshot-settings.png)
Animation, font, time format, colour mode (dark/light/system), alarm and timer sounds, per-screen colour, keyboard shortcuts.

</div>

</div>

---

## Features

<div class="feature-grid">

<div class="feature">

#### Animated Backgrounds

Five styles — Lava Lamp, Raindrops, Bubbles, Breath, or None. Bubbles runs on the GPU via GLSL. Breath is a morphing organic blob. Speed, density, and amplitude are tunable.

</div>

<div class="feature">

#### Per-Screen Colour

Each screen gets its own colour. Pick from named presets (blue, purple, green) or dial in a custom hue. Independent settings for dark and light modes.

</div>

<div class="feature">

#### Sound Selection

Android pulls ringtones directly from the system. On Linux, any `.oga` or `.wav` in `/usr/share/sounds/freedesktop/stereo` is available. Separate pickers for alarm and timer.

</div>

<div class="feature">

#### 24h / 12h Format

One tap in settings. Applies everywhere — Clock, World Clock, alarm list, and time picker.

</div>

<div class="feature">

#### Saved Timer Presets

Name presets with emoji shortcodes — `:tea:`, `:pomodoro:`, `:pizza:`. Type `:te` and a suggestion row appears. New presets activate immediately on save. Edge pills auto-hide after 3 seconds.

</div>

<div class="feature">

#### Keyboard Navigation

Arrow keys cycle screens. Bindings are configurable. Disabled automatically while typing.

</div>

<div class="feature">

#### Settings Overlay

Tap anywhere to reveal the gear icon. It hides after 3 seconds. The sheet covers animation, font, time format, colour mode, sounds, per-screen colour, and keyboard bindings.

</div>

<div class="feature">

#### Config File

JSON at `~/.config/noctua/noctua_config.json` (Linux) or app documents (Android). Hand-edit if you want.

</div>

</div>

---

## Getting Started {#getting-started}

### Requirements

| Platform | Minimum |
|----------|---------|
| Linux    | GTK 3, PulseAudio (`paplay`) |
| Android  | API 21 (Android 5.0) |

### Linux (from source)

```bash
git clone https://github.com/opennomad/noctua.git
cd noctua
mise exec -- flutter run -d linux
```

[mise](https://mise.jdx.dev/) manages the Flutter and Dart toolchain. Install it first if you haven't, then run `mise install` in the project root.

### Android

```bash
mise exec -- flutter run
```

On first launch Noctua requests **notification**, **exact alarm**, and **full-screen intent** permissions. All three are needed for alarms to fire and show on the lock screen.

---

## Technical

Built with [Flutter](https://flutter.dev) 3.41 / Dart 3.11.

| Package | Purpose |
|---------|---------|
| `flutter_local_notifications` | Alarm and timer notifications on Android |
| `timezone` | DST-correct world clock and alarm scheduling |
| `google_fonts` | Runtime font loading |
| `path_provider` · `xdg_directories` | Platform config paths |

Source: [github.com/opennomad/noctua](https://github.com/opennomad/noctua)

---

*Noctua — named for the little owl.*

