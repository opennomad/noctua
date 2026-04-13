import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/color_schemes.dart';

class _Blob {
  final double baseX;
  final double baseY;
  final double ampX;
  final double ampY;
  final double freqX;
  final double freqY;
  final double phaseX;
  final double phaseY;
  final double radius;
  final Color color;

  const _Blob({
    required this.baseX,
    required this.baseY,
    required this.ampX,
    required this.ampY,
    required this.freqX,
    required this.freqY,
    required this.phaseX,
    required this.phaseY,
    required this.radius,
    required this.color,
  });

  Offset position(double t) {
    return Offset(
      baseX + ampX * sin(freqX * t * 2 * pi + phaseX),
      baseY + ampY * sin(freqY * t * 2 * pi + phaseY),
    );
  }
}

class LavaLampBackground extends StatefulWidget {
  final NoctuaColorScheme scheme;

  const LavaLampBackground({super.key, required this.scheme});

  @override
  State<LavaLampBackground> createState() => _LavaLampBackgroundState();
}

class _LavaLampBackgroundState extends State<LavaLampBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Blob> _blobs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _buildBlobs();
  }

  void _buildBlobs() {
    final s = Color.fromARGB(179, widget.scheme.secondary.r.toInt(),
        widget.scheme.secondary.g.toInt(), widget.scheme.secondary.b.toInt());
    final a = Color.fromARGB(89, widget.scheme.accent.r.toInt(),
        widget.scheme.accent.g.toInt(), widget.scheme.accent.b.toInt());
    final am = Color.fromARGB(64, widget.scheme.accent.r.toInt(),
        widget.scheme.accent.g.toInt(), widget.scheme.accent.b.toInt());

    _blobs = [
      _Blob(baseX: 0.20, baseY: 0.30, ampX: 0.15, ampY: 0.20,
            freqX: 1.0, freqY: 0.70, phaseX: 0.0, phaseY: 1.0,
            radius: 0.30, color: s),
      _Blob(baseX: 0.72, baseY: 0.60, ampX: 0.18, ampY: 0.15,
            freqX: 0.8, freqY: 1.10, phaseX: 2.0, phaseY: 0.5,
            radius: 0.34, color: a),
      _Blob(baseX: 0.50, baseY: 0.82, ampX: 0.22, ampY: 0.14,
            freqX: 1.3, freqY: 0.90, phaseX: 1.0, phaseY: 3.0,
            radius: 0.26, color: s),
      _Blob(baseX: 0.30, baseY: 0.70, ampX: 0.14, ampY: 0.22,
            freqX: 0.6, freqY: 1.40, phaseX: 4.0, phaseY: 1.5,
            radius: 0.22, color: am),
      _Blob(baseX: 0.80, baseY: 0.20, ampX: 0.12, ampY: 0.18,
            freqX: 1.5, freqY: 0.50, phaseX: 2.5, phaseY: 2.0,
            radius: 0.24, color: s),
      _Blob(baseX: 0.55, baseY: 0.40, ampX: 0.20, ampY: 0.16,
            freqX: 0.9, freqY: 1.20, phaseX: 3.2, phaseY: 0.8,
            radius: 0.20, color: a),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _LavaLampPainter(
            blobs: _blobs,
            t: _controller.value,
            background: widget.scheme.primary,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _LavaLampPainter extends CustomPainter {
  final List<_Blob> blobs;
  final double t;
  final Color background;

  const _LavaLampPainter({
    required this.blobs,
    required this.t,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = background,
    );

    for (final blob in blobs) {
      final pos = blob.position(t);
      final center = Offset(pos.dx * size.width, pos.dy * size.height);
      final radius = blob.radius * size.shortestSide;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            blob.color,
            Color.fromARGB(0, blob.color.r.toInt(), blob.color.g.toInt(),
                blob.color.b.toInt()),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_LavaLampPainter old) => old.t != t;
}
