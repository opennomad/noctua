# noctua

A Flutter clock app for Android with animated backgrounds and a clean, minimal UI.

## Screens

Three columns navigable by horizontal swipe:

| Column | Primary | Secondary (swipe up) |
|--------|---------|----------------------|
| Clock  | Digital clock + date | World Clock |
| Alarm  | Alarm list | Night Clock |
| Timer  | Timer | Stopwatch |

## Features

- **Animated backgrounds** — Lava Lamp, Raindrops, Wave, Pulse, or None
- **Per-column colour schemes** — full hue picker; blue / purple / green presets as defaults
- **Font selection** — Default, Orbitron, Raleway, Oxanium, Mono, Exo 2
- **World Clock** — searchable city picker (115 cities), IANA timezone aware (DST-correct), custom UTC offset entry, reorderable / deletable list
- **Alarms** — add/edit/delete alarms with optional label, one-shot or recurring by day of week; scheduled via `flutter_local_notifications`
- **Night Clock** — dimmed full-screen clock with animated background for bedside use
- **Timer** — scroll-drum time input (h / m / s); saved timers as auto-hiding edge pills; simultaneous running timers; +1 m button; `:shortcode:` emoji syntax in timer names (`:tea:`, `:todo:`, etc.)
- **Stopwatch** — lap recording; stable fixed-width layout prevents horizontal jitter
- **Keyboard navigation** — arrow keys (configurable) move between columns and screens; disabled while text fields or modals are focused
- **Settings overlay** — gear icon fades in on touch, auto-hides after 3 s; opens a bottom-sheet panel with keyboard binding editor and timer-pill edge selector
- **Config file** — human-readable JSON; `~/.config/noctua/noctua_config.json` on Linux, app documents dir on Android

## Running

```bash
mise exec -- flutter run -d linux     # desktop dev
mise exec -- flutter run              # connected Android device
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `path_provider` | Locate config directory on non-Linux platforms |
| `xdg_directories` | XDG config path on Linux |
| `google_fonts` | Runtime font loading |
| `timezone` | IANA timezone database (DST-correct world clock & alarm scheduling) |
| `flutter_local_notifications` | Android alarm scheduling |
