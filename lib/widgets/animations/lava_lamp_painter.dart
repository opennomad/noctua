import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/color_schemes.dart';
import '../../config/noctua_config.dart';

class Blob {
  final double bx, by, ax, ay, fx, fy, px, py, r;
  final Color color;

  const Blob(this.bx, this.by, this.ax, this.ay, this.fx, this.fy, this.px,
      this.py, this.r, this.color);

  Offset pos(double t) => Offset(
        bx + ax * sin(fx * t * 2 * pi + px),
        by + ay * sin(fy * t * 2 * pi + py),
      );
}

List<Blob> buildBlobs(NoctuaColorScheme s, AnimationParams p) {
  final am = p.amplitude;
  return [
    Blob(0.20, 0.30, 0.15, 0.20, 1.0, 0.70, 0.0, 1.0, 0.30 * am, s.secondary.withAlpha(179)),
    Blob(0.72, 0.60, 0.18, 0.15, 0.8, 1.10, 2.0, 0.5, 0.34 * am, s.accent.withAlpha(89)),
    Blob(0.50, 0.82, 0.22, 0.14, 1.3, 0.90, 1.0, 3.0, 0.26 * am, s.secondary.withAlpha(128)),
    Blob(0.30, 0.70, 0.14, 0.22, 0.6, 1.40, 4.0, 1.5, 0.22 * am, s.accent.withAlpha(64)),
    Blob(0.80, 0.20, 0.12, 0.18, 1.5, 0.50, 2.5, 2.0, 0.24 * am, s.secondary.withAlpha(153)),
    Blob(0.55, 0.40, 0.20, 0.16, 0.9, 1.20, 3.2, 0.8, 0.20 * am, s.accent.withAlpha(89)),
  ];
}

class LavaLampPainter extends CustomPainter {
  final List<Blob> blobs;
  final double t;
  final Color bg;

  const LavaLampPainter(this.blobs, this.t, this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bg,
    );
    for (final b in blobs) {
      final p = b.pos(t);
      final center = Offset(p.dx * size.width, p.dy * size.height);
      final r = b.r * size.shortestSide;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [b.color, b.color.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(LavaLampPainter old) => old.t != t;
}
