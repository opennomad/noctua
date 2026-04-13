import 'dart:async';
import 'package:flutter/material.dart';

enum _TimerStatus { idle, running, paused }

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  static const _presets = [60, 300, 600, 1800, 3600]; // seconds

  Duration _set = const Duration(minutes: 5);
  Duration _remaining = const Duration(minutes: 5);
  _TimerStatus _status = _TimerStatus.idle;
  Timer? _ticker;

  void _startOrResume() {
    if (_remaining == Duration.zero) return;
    setState(() => _status = _TimerStatus.running);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds <= 1) {
        _ticker?.cancel();
        setState(() {
          _remaining = Duration.zero;
          _status = _TimerStatus.idle;
        });
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _status = _TimerStatus.paused);
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _remaining = _set;
      _status = _TimerStatus.idle;
    });
  }

  void _adjustMinutes(int delta) {
    if (_status != _TimerStatus.idle) return;
    final new_seconds = (_set.inSeconds + delta * 60).clamp(60, 3600 * 24);
    setState(() {
      _set = Duration(seconds: new_seconds);
      _remaining = _set;
    });
  }

  String get _display {
    final h = _remaining.inHours;
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final is_idle = _status == _TimerStatus.idle;
    final is_running = _status == _TimerStatus.running;

    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Duration display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (is_idle)
                _IconBtn(
                    icon: Icons.remove,
                    onTap: () => _adjustMinutes(-1)),
              const SizedBox(width: 16),
              Text(
                _display,
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w100,
                  letterSpacing: 4,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              if (is_idle)
                _IconBtn(
                    icon: Icons.add,
                    onTap: () => _adjustMinutes(1)),
            ],
          ),

          const SizedBox(height: 16),

          // Presets
          if (is_idle)
            Wrap(
              spacing: 12,
              children: _presets.map((s) {
                final label = s < 3600
                    ? '${s ~/ 60}m'
                    : '${s ~/ 3600}h';
                return GestureDetector(
                  onTap: () => setState(() {
                    _set = Duration(seconds: s);
                    _remaining = _set;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withAlpha(77), width: 1),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                          color: Colors.white.withAlpha(178), fontSize: 13),
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 48),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!is_idle) ...[
                _IconBtn(icon: Icons.refresh, onTap: _reset, size: 28),
                const SizedBox(width: 32),
              ],
              _BigBtn(
                icon: is_running ? Icons.pause : Icons.play_arrow,
                onTap: is_running ? _pause : _startOrResume,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _IconBtn({required this.icon, required this.onTap, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white.withAlpha(178), size: size),
    );
  }
}

class _BigBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BigBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(102), width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: 36),
      ),
    );
  }
}
