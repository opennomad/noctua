import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/noctua_config.dart';
import '../../theme/color_schemes.dart';

/// A wave source placed far off-screen.
///
/// Because the center is 2–3 screen-widths outside the visible area, only the
/// arc edge ever crosses the screen — it appears as a broad, nearly-straight
/// wavefront sweeping in one direction, exactly like a water wave viewed from
/// above.  Multiple sources from different compass angles produce a crossing,
/// interference-like pattern.
class Wave {
  final double bx, by;                   // base position in width-normalised coords
  final double ax, ay, fx, fy, px, py;   // Lissajous drift (slowly rotates wave angle)
  final double phase;                    // cycle offset — staggers sources
  final double max_r;                    // ring radius limit in longestSide units
  final int rings;                       // rings per source (continuous coverage)
  final double base_opacity;             // peak opacity per ring
  final Color color;

  const Wave(this.bx, this.by, this.ax, this.ay, this.fx, this.fy, this.px,
      this.py, this.phase, this.max_r, this.rings, this.base_opacity, this.color);

  Offset position(double t) => Offset(
        bx + ax * sin(fx * t * 2 * pi + px),
        by + ay * sin(fy * t * 2 * pi + py),
      );
}

List<Wave> buildWaves(NoctuaColorScheme s, AnimationParams p) {
  var seed = 7;
  double rnd() {
    seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (seed & 0xFFFFFF) / 0xFFFFFF;
  }

  // Cap at 4 sources — 5 rarely adds visible variety but costs 25 % more GPU.
  final count = (2 + p.density * 2).round().clamp(2, 4);

  // All sources cluster on the same side so every front travels in the same
  // direction — like wind-driven waves on open water.
  // base_angle picks a random dominant origin direction; each source varies
  // by at most ±30° so fronts are nearly parallel.
  final base_angle = rnd() * 2 * pi;

  return List.generate(count, (i) {
    final angle = base_angle + (rnd() - 0.5) * (pi / 6);

    // Distance from screen centre in screen-width units.  2.0–2.6 keeps the
    // source well off-screen; arcs enter the visible area at roughly ring_t 0.5.
    final dist = 2.0 + rnd() * 0.6;
    final bx = 0.5 + cos(angle) * dist;
    final by = 0.5 + sin(angle) * dist;

    // max_r in longestSide units: must reach the far corner of the screen from
    // this source, with a little extra so rings finish well past the edge.
    // 3.0–3.7 covers all portrait and landscape aspect ratios.
    final max_r = 3.0 + rnd() * 0.7;

    // Ring is only visible for roughly 35–40 % of its cycle (the stretch when
    // the arc is crossing the screen), so base_opacity is kept higher than for
    // on-screen sources.  Amplitude scales intensity.
    final base_opacity = (0.28 + rnd() * 0.15) * p.amplitude;

    return Wave(
      bx, by,
      0.05 + rnd() * 0.08,  // ax: small drift — doesn't shift apparent wave direction much
      0.05 + rnd() * 0.08,  // ay
      0.04 + rnd() * 0.06,  // fx: very slow
      0.03 + rnd() * 0.05,  // fy
      rnd() * 2 * pi,       // px
      rnd() * 2 * pi,       // py
      i / count,            // phase: stagger ring sets across sources
      max_r,
      3,                    // 3 rings — at ~38 % visibility each, ~1.1 rings on-screen
      base_opacity,
      i.isEven ? s.secondary : s.accent,
    );
  });
}

// ─── per-ring glow approximation ─────────────────────────────────────────────
//
// MaskFilter.blur is O(pixels × sigma²) — catastrophically slow on large
// screens.  Instead we stack a handful of concentric transparent strokes,
// each a bit wider and more transparent than the last, to simulate the
// Gaussian falloff.  Cost is O(draw_calls) regardless of screen resolution.
//
// Layers (back → front):
//   diffuse  wide, very low α  — broad halo behind the wavefront
//   mid      medium, mid α     — intermediate glow
//   inner    narrower, higher α — tight glow hugging the crest
//   crest    thin, full α      — sharp leading edge

const List<({double r_off, double sw_mul, double a_mul})> _glow_layers = [
  (r_off: -2.80, sw_mul: 5.5, a_mul: 0.06),  // diffuse
  (r_off: -1.60, sw_mul: 3.5, a_mul: 0.14),  // mid
  (r_off: -0.55, sw_mul: 2.0, a_mul: 0.26),  // inner
];

class WavePainter extends CustomPainter {
  final List<Wave> waves;
  final double t;
  final Color bg;

  const WavePainter(this.waves, this.t, this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bg,
    );

    for (final w in waves) {
      final pos = w.position(t);
      // x is width-normalised, y is height-normalised — source stays off-screen
      // regardless of aspect ratio.
      final center = Offset(pos.dx * size.width, pos.dy * size.height);
      final max_r = w.max_r * size.longestSide;

      // Pre-compute screen distance bounds for this source so ring culling is
      // O(1) — skips rings that haven't entered or have already left the screen.
      final nx = center.dx.clamp(0.0, size.width);
      final ny = center.dy.clamp(0.0, size.height);
      final min_screen_dist = (center - Offset(nx, ny)).distance;
      final max_screen_dist = [
        (center - Offset(0, 0)).distance,
        (center - Offset(size.width, 0)).distance,
        (center - Offset(0, size.height)).distance,
        (center - Offset(size.width, size.height)).distance,
      ].reduce(max);

      for (int i = 0; i < w.rings; i++) {
        final ring_t = (t + w.phase + i / w.rings) % 1.0;
        final radius = ring_t * max_r;
        if (radius < 4.0) continue;

        final alpha = ((1.0 - ring_t) * w.base_opacity * 255).round().clamp(0, 255);
        if (alpha < 2) continue;

        final stroke_w = 4.0 + (1.0 - ring_t) * 8.0;

        // Cull: ring hasn't reached the screen yet.
        if (radius + stroke_w * 5.5 < min_screen_dist) continue;

        // Cull: ring has swept entirely past the screen.
        if (radius - stroke_w * 5.5 > max_screen_dist) continue;

        // Glow layers — stacked transparent strokes, widest first.
        for (final layer in _glow_layers) {
          final r = max(0.0, radius + layer.r_off * stroke_w);
          canvas.drawCircle(
            center, r,
            Paint()
              ..style      = PaintingStyle.stroke
              ..strokeWidth = stroke_w * layer.sw_mul
              ..color      = w.color.withAlpha(
                  (alpha * layer.a_mul).round().clamp(0, 255)),
          );
        }

        // Sharp crest on top.
        canvas.drawCircle(
          center, radius,
          Paint()
            ..style      = PaintingStyle.stroke
            ..strokeWidth = stroke_w
            ..color      = w.color.withAlpha(alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(WavePainter old) => old.t != t;
}
