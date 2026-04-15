import 'package:flutter/material.dart';
import '../config/noctua_config.dart';
import '../theme/color_schemes.dart';
import 'animations/lava_lamp_painter.dart' show Blob, LavaLampPainter, buildBlobs;
import 'animations/raindrops_painter.dart' show Drop, RaindropsPainter, buildDrops;
import 'animations/wave_painter.dart' show Wave, WavePainter, buildWaves;
import 'animations/pulse_painter.dart' show PulsePainter, ringCount;

/// Animated full-screen background driven by [NoctuaConfig].
///
/// Supported [animation] values: 'lava_lamp', 'raindrops', 'wave', 'pulse'.
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
  late List<Wave> _waves;

  // Base cycle duration in seconds for each animation at speed = 1.0.
  static const _base_seconds = {
    'raindrops': 6.0,
    'wave':      12.0,
    'pulse':     6.0,
  };
  static const _lava_base = 20.0;

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
  }

  @override
  void didUpdateWidget(AnimatedBackground old) {
    super.didUpdateWidget(old);
    if (old.scheme     != widget.scheme     ||
        old.animation  != widget.animation  ||
        old.params.density   != widget.params.density   ||
        old.params.amplitude != widget.params.amplitude) {
      _initElements();
    }
    // Speed changes are picked up automatically via _cycle_seconds.
  }

  void _initElements() {
    _blobs = buildBlobs(widget.scheme, widget.params);
    _drops = buildDrops(widget.scheme, widget.params);
    _waves = buildWaves(widget.scheme, widget.params);
  }

  CustomPainter _painter(double t) => switch (widget.animation) {
        'raindrops' => RaindropsPainter(_drops, t, widget.scheme.primary),
        'wave'      => WavePainter(_waves, t, widget.scheme.primary),
        'pulse'     => PulsePainter(
            t,
            widget.scheme.primary,
            widget.scheme.accent,
            widget.params.amplitude,
            ringCount(widget.params),
          ),
        'none'      => _SolidPainter(widget.scheme.primary),
        _           => LavaLampPainter(_blobs, t, widget.scheme.primary),
      };

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
