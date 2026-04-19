import 'dart:math';
import 'package:flutter/material.dart';

/// Organic breathing blob: a morphing amoeba shape that swells from ~55% of
/// the shorter screen dimension to ~90% and back, with continuously changing
/// organic deformation driven by incommensurable sine harmonics.
class BreathPainter extends CustomPainter {
  final double t;          // fractional cycle count (monotonically increasing)
  final Color  bg;
  final Color  color_a;    // secondary — centre tint
  final Color  color_b;    // accent   — edge tint / glow
  final double amplitude;  // overall colour intensity multiplier
  final double density;    // shape-complexity multiplier

  const BreathPainter(
    this.t, this.bg, this.color_a, this.color_b, {
    this.amplitude = 1.0,
    this.density   = 1.0,
  });

  // Number of boundary sample points — 96 gives a smooth silhouette.
  static const _n = 96;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bg,
    );

    final center   = Offset(size.width / 2, size.height / 2);
    final half_min = min(size.width, size.height) / 2;

    // ── breathing: smooth cosine from min (55 %) to max (90 %) of half_min ──
    // At t=0  → min size.  At t=0.5 → max size.  At t=1 → min size again.
    final breath = 0.5 - 0.5 * cos(t * 2 * pi);  // 0→1→0 per cycle
    final base_r = half_min * (0.55 + 0.35 * breath);

    // ── harmonic deformation rates (incommensurable → never exactly repeats) ──
    final tau = t * 2 * pi;
    final amp = density.clamp(0.2, 2.0);

    // Compute organic boundary points.
    final pts = List.generate(_n, (i) {
      final theta = i * 2 * pi / _n;
      double r = base_r;
      // Primary lobes — always present.
      r += base_r * 0.09  * amp * sin(3  * theta + tau * 0.710);
      r += base_r * 0.065 * amp * sin(5  * theta - tau * 0.530 + 1.20);
      r += base_r * 0.050 * amp * sin(7  * theta + tau * 0.430 + 2.30);
      r += base_r * 0.040 * amp * sin(2  * theta - tau * 0.310 + 0.70);
      // Fine detail — scales with density.
      r += base_r * 0.025 * amp * sin(11 * theta + tau * 0.670 + 3.10);
      r += base_r * 0.018 * amp * sin(13 * theta - tau * 0.490 + 1.80);
      r += base_r * 0.012 * amp * sin(17 * theta + tau * 0.370 + 4.20);
      return Offset(
        center.dx + r * cos(theta),
        center.dy + r * sin(theta),
      );
    });

    // ── smooth closed path through boundary points ────────────────────────────
    // Each segment is a quadratic Bézier with the sample point as the control
    // and the midpoints to adjacent samples as start/end knots.
    final path = Path();
    final start = _mid(pts[_n - 1], pts[0]);
    path.moveTo(start.dx, start.dy);
    for (var i = 0; i < _n; i++) {
      final p    = pts[i];
      final mid  = _mid(p, pts[(i + 1) % _n]);
      path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
    }
    path.close();

    final alpha = amplitude.clamp(0.0, 2.0);

    // ── soft glow (two passes) ────────────────────────────────────────────────
    // Outer diffuse halo — keeps sigma modest so the inward blur doesn't
    // bleed too far into the blob interior.
    canvas.drawPath(
      path,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..color       = color_b.withAlpha((alpha * 50).round().clamp(0, 255))
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    // Inner crisp ring — tighter, slightly brighter.
    canvas.drawPath(
      path,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..color       = color_b.withAlpha((alpha * 80).round().clamp(0, 255))
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // ── filled blob — feathered boundary via MaskFilter on the fill ──────────
    // BlurStyle.normal blurs the coverage mask so the path boundary dissolves
    // rather than hard-clips. sigma=22 gives ~22 px of fade on each side.
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color_b.withAlpha((alpha * 200).round().clamp(0, 255)),
            color_a.withAlpha((alpha * 178).round().clamp(0, 255)),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: base_r * 1.18))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
  }

  static Offset _mid(Offset a, Offset b) =>
      Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

  @override
  bool shouldRepaint(BreathPainter old) =>
      old.t != t || old.amplitude != amplitude || old.density != density;
}
