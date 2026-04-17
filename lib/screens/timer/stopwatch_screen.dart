import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/color_schemes.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final _stopwatch = Stopwatch();
  Timer? _ticker;
  final List<Duration> _laps = [];

  void _startStop() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _ticker?.cancel();
      setState(() {});
    } else {
      _stopwatch.start();
      _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
        setState(() {});
      });
    }
  }

  void _lap() {
    if (!_stopwatch.isRunning) return;
    setState(() => _laps.insert(0, _stopwatch.elapsed));
  }

  void _reset() {
    _stopwatch.stop();
    _ticker?.cancel();
    setState(() {
      _stopwatch.reset();
      _laps.clear();
    });
  }

  String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$ms';
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _ticker?.cancel();
    super.dispose();
  }

  // Renders [time] centred inside a frame permanently sized to '00:00.00' so
  // the layout never shifts as digits change, regardless of tnum font support.
  Widget _stableTime(String time, TextStyle style) => Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: Text('00:00.00', style: style)),
          Text(time, style: style),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final time_style = TextStyle(
      fontSize: 64,
      fontWeight: FontWeight.w100,
      letterSpacing: 4,
      color: noctuaText(context),
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return SafeArea(
      child: Column(
        children: [
          const Spacer(),
          _stableTime(_format(_stopwatch.elapsed), time_style),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_stopwatch.elapsed > Duration.zero) ...[
                _CircleBtn(
                  icon: _stopwatch.isRunning ? Icons.flag : Icons.refresh,
                  onTap: _stopwatch.isRunning ? _lap : _reset,
                  small: true,
                ),
                const SizedBox(width: 32),
              ],
              _CircleBtn(
                icon: _stopwatch.isRunning ? Icons.pause : Icons.play_arrow,
                onTap: _startStop,
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_laps.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _laps.length,
                padding: const EdgeInsets.symmetric(horizontal: 48),
                itemBuilder: (context, i) {
                  final lap_num = _laps.length - i;
                  final prev = i < _laps.length - 1 ? _laps[i + 1] : Duration.zero;
                  final split = _laps[i] - prev;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lap $lap_num',
                          style: TextStyle(
                            color: noctuaText(context).withAlpha(128),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _format(split),
                          style: TextStyle(
                            color: noctuaText(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool small;

  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 52.0 : 72.0;
    final icon_size = small ? 24.0 : 36.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: noctuaText(context).withAlpha(102), width: small ? 1 : 1.5),
        ),
        child: Icon(icon, color: noctuaText(context), size: icon_size),
      ),
    );
  }
}
