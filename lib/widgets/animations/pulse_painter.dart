import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/noctua_config.dart';

int ringCount(AnimationParams p) => (3 * p.density).round().clamp(2, 9);

class PulsePainter extends CustomPainter {
  final double t;
  final Color bg;
  final Color ring_color;
  final double amplitude;
  final int rings;

  const PulsePainter(this.t, this.bg, this.ring_color, this.amplitude, this.rings);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bg,
    );

    final center = Offset(size.width / 2, size.height / 2);
    // Extend slightly past the screen diagonal so rings fully dissolve before
    // they'd otherwise hard-clip at the visible edge.
    final max_r = size.longestSide * 0.78 * amplitude;

    _drawCenterGlow(canvas, center, max_r * 0.10);

    for (int i = 0; i < rings; i++) {
      final phase = (t + i / rings) % 1.0;
      final radius = phase * max_r;
      if (radius < 4.0) continue;

      // Fade in over the first 20 % of travel, fade out for the remainder —
      // rings emerge softly from the center and dissolve before reaching the edge.
      final env = phase < 0.2
          ? phase / 0.2
          : (1.0 - phase) / 0.8;
      final base_alpha = (env * 0.45 * 255).round().clamp(0, 255);
      if (base_alpha < 2) continue;

      final stroke_w = 1.0 + (1.0 - phase) * 2.5;
      final blur = 4.0 + phase * 10.0;

      // Broad soft wake behind the crest.
      final wake_alpha = (base_alpha * 0.30).round().clamp(0, 255);
      canvas.drawCircle(
        center,
        radius - stroke_w * 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke_w * 7.0
          ..color = ring_color.withAlpha(wake_alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 3.5),
      );

      // Crest.
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke_w
          ..color = ring_color.withAlpha(base_alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }
  }

  // Soft filled glow at the origin that breathes in sync with the ring cycle.
  void _drawCenterGlow(Canvas canvas, Offset center, double radius) {
    final pulse = sin(t * 2 * pi) * 0.5 + 0.5;

    // Gentle breathing glow at the origin.
    canvas.drawCircle(
      center,
      radius * (0.6 + 0.3 * pulse),
      Paint()
        ..style = PaintingStyle.fill
        ..color = ring_color.withAlpha((20 + 25 * pulse).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
  }

  @override
  bool shouldRepaint(PulsePainter old) => old.t != t;
}
