import 'dart:ui' show FragmentProgram;
import 'package:flutter/material.dart';
import '../config/noctua_config.dart';
import '../theme/color_schemes.dart';
import 'animations/lava_lamp_painter.dart' show Blob, LavaLampPainter, buildBlobs;
import 'animations/raindrops_painter.dart' show Drop, RaindropsPainter, buildDrops;
import 'animations/breath_painter.dart' show BreathPainter;
import 'animations/bubbles_painter.dart' show BubblesPainter;

/// Animated full-screen background driven by [NoctuaConfig].
///
/// Supported [animation] values: 'lava_lamp', 'raindrops', 'bubbles', 'breath', 'none'.
///
/// Time is supplied externally via [time] — a [ValueNotifier] updated by a
/// single ticker in the parent [StackNav].  This means all [AnimatedBackground]
/// instances share one ticker and are always phase-matched, and only the
/// [CustomPaint] inside each instance repaints each frame (not the whole tree).
class AnimatedBackground extends StatefulWidget {
  final NoctuaColorScheme scheme;
  final String animation;
  final AnimationParams params;

  /// Monotonically increasing elapsed seconds, driven by [StackNav]'s ticker.
  final ValueNotifier<double> time;

  const AnimatedBackground({
    super.key,
    required this.scheme,
    required this.animation,
    required this.params,
    required this.time,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> {
  late List<Blob> _blobs;
  late List<Drop> _drops;

  // Base cycle duration in seconds for each animation at speed = 1.0.
  static const _base_seconds = {
    'raindrops': 6.0,
    'bubbles':   2.0,   // one full screen crossing in 2 s
    'breath':    6.0,
  };
  static const _lava_base = 20.0;

  FragmentProgram? _bubbles_program;

  double get _cycle_seconds {
    final base = _base_seconds[widget.animation] ?? _lava_base;
    return base / widget.params.speed.clamp(0.1, 10.0);
  }

  // Fractional cycle count — never resets.
  double _t(double elapsed_s) => elapsed_s / _cycle_seconds;

  @override
  void initState() {
    super.initState();
    _initElements();
    _loadBubbles();
  }

  Future<void> _loadBubbles() async {
    try {
      final prog = await FragmentProgram.fromAsset('assets/shaders/bubbles.frag');
      if (mounted) setState(() => _bubbles_program = prog);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(AnimatedBackground old) {
    super.didUpdateWidget(old);
    if (old.scheme             != widget.scheme             ||
        old.animation          != widget.animation          ||
        old.params.density     != widget.params.density     ||
        old.params.amplitude   != widget.params.amplitude) {
      _initElements();
    }
    // Speed changes are picked up automatically via _cycle_seconds.
  }

  void _initElements() {
    _blobs = buildBlobs(widget.scheme, widget.params);
    _drops = buildDrops(widget.scheme, widget.params);
  }

  CustomPainter _painter(double t) {
    final s = widget.scheme;
    final p = widget.params;
    return switch (widget.animation) {
      'raindrops' => RaindropsPainter(_drops, t, s.primary),
      'breath'    => BreathPainter(
          t, s.primary, s.secondary, s.accent,
          amplitude: p.amplitude,
          density:   p.density,
        ),
      'bubbles'   => _bubbles_program != null
          ? BubblesPainter(
              _bubbles_program!, t, s.primary, s.secondary, s.accent,
              amplitude: p.amplitude,
              density:   p.density,
            )
          : _SolidPainter(s.primary),
      'none'      => _SolidPainter(s.primary),
      _           => LavaLampPainter(_blobs, t, s.primary),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.time,
      builder: (context, elapsed_s, child) => CustomPaint(
        painter: _painter(widget.animation == 'none' ? 0 : _t(elapsed_s)),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SolidPainter extends CustomPainter {
  final Color bg;
  const _SolidPainter(this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bg,
    );
  }

  @override
  bool shouldRepaint(_SolidPainter old) => old.bg != bg;
}
