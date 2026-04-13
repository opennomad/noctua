import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
/// Uses a [Ticker] rather than a repeating [AnimationController] so that the
/// time value passed to painters is monotonically increasing. This prevents
/// the hard visual reset that occurs when a looping controller jumps from
/// t=1 back to t=0 while particles are still visible.
class AnimatedBackground extends StatefulWidget {
  final NoctuaColorScheme scheme;
  final String animation;
  final AnimationParams params;

  const AnimatedBackground({
    super.key,
    required this.scheme,
    required this.animation,
    required this.params,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _elapsed = Duration.zero;

  late List<Blob> _blobs;
  late List<Drop> _drops;
  late List<Wave> _waves;

  // Base cycle duration in seconds for each animation at speed = 1.0
  static const _base_seconds = {
    'raindrops': 6.0,
    'wave': 12.0,
    'pulse': 6.0,
  };
  static const _lava_base = 20.0;

  double get _cycle_seconds {
    final base = _base_seconds[widget.animation] ?? _lava_base;
    return base / widget.params.speed.clamp(0.1, 10.0);
  }

  // Monotonically increasing fractional cycle count — never resets.
  double get _t => _elapsed.inMicroseconds / 1e6 / _cycle_seconds;

  @override
  void initState() {
    super.initState();
    _initElements();
    _ticker = createTicker((elapsed) {
      setState(() => _elapsed = elapsed);
    })..start();
  }

  void _initElements() {
    _blobs = buildBlobs(widget.scheme, widget.params);
    _drops = buildDrops(widget.scheme, widget.params);
    _waves = buildWaves(widget.scheme, widget.params);
  }

  @override
  void didUpdateWidget(AnimatedBackground old) {
    super.didUpdateWidget(old);
    if (old.scheme != widget.scheme ||
        old.animation != widget.animation ||
        old.params.density != widget.params.density ||
        old.params.amplitude != widget.params.amplitude) {
      _initElements();
    }
    // Speed changes are picked up automatically via _cycle_seconds — no restart needed.
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
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
    return CustomPaint(
      painter: _painter(widget.animation == 'none' ? 0 : _t),
      child: const SizedBox.expand(),
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
