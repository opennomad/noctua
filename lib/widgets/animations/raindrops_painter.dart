import 'package:flutter/material.dart';
import '../../config/noctua_config.dart';
import '../../theme/color_schemes.dart';

class Drop {
  final double phase;   // independent cycle offset (0–1) — staggers resets
  final double max_r;   // max ring radius as fraction of shortest screen side
  final double opacity; // peak opacity (0–1)
  final Color color;

  const Drop(this.phase, this.max_r, this.opacity, this.color);
}

List<Drop> buildDrops(NoctuaColorScheme s, AnimationParams p) {
  var seed = 42;
  double rnd() {
    seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (seed & 0xFFFFFF) / 0xFFFFFF;
  }

  final count = (5 * p.density).round().clamp(2, 16);
  return List.generate(count, (i) => Drop(
        rnd(),
        (0.12 + rnd() * 0.13) * p.amplitude,
        0.22 + rnd() * 0.18,
        i.isEven ? s.secondary : s.accent,
      ));
}

// Fast 32-bit integer hash → 0.0–1.0
double _h(int n) {
  n = ((n ^ (n >> 16)) * 0x45d9f3b) & 0xFFFFFFFF;
  n = ((n ^ (n >> 16)) * 0x45d9f3b) & 0xFFFFFFFF;
  n =  (n ^ (n >> 16))              & 0xFFFFFFFF;
  return n / 0xFFFFFFFF;
}

class RaindropsPainter extends CustomPainter {
  final List<Drop> drops;
  final double t;
  final Color bg;

  const RaindropsPainter(this.drops, this.t, this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bg,
    );

    for (int i = 0; i < drops.length; i++) {
      final d = drops[i];
      final cycle_t = t + d.phase;
      final ring_t  = cycle_t % 1.0;
      final cycle   = cycle_t.floor(); // increments each full loop

      final radius = ring_t * d.max_r * size.shortestSide;
      if (radius < 4.0) continue;

      // New screen position each cycle, derived from drop index + cycle number.
      // The jump happens while the ring is invisible (radius < 4px), so it's seamless.
      final cx = (0.05 + _h(i * 9973 + cycle * 1031)        * 0.90) * size.width;
      final cy = (0.05 + _h(i * 9973 + cycle * 1031 + 4999) * 0.90) * size.height;

      final alpha    = ((1.0 - ring_t) * d.opacity * 255).round().clamp(0, 255);
      if (alpha < 3) continue;

      final stroke_w = (1.0 - ring_t) * 3.0 + 0.4;
      final blur     = (1.0 - ring_t) * 5.0 + 1.0;

      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke_w
          ..color = d.color.withAlpha(alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }
  }

  @override
  bool shouldRepaint(RaindropsPainter old) => old.t != t;
}
