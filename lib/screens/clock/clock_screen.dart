import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/color_schemes.dart';
import '../../config/config_service.dart';

class ClockScreen extends StatefulWidget {
  final ConfigService config_service;
  const ClockScreen({super.key, required this.config_service});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen>
    with SingleTickerProviderStateMixin {
  static const _hide_delay = Duration(seconds: 3);
  static const _fade_ms    = Duration(milliseconds: 300);

  late AnimationController _fade_ctrl;
  late Animation<double>   _fade;
  Timer? _fade_timer;

  late DateTime _now;
  late Timer    _clock_timer;

  @override
  void initState() {
    super.initState();
    _fade_ctrl = AnimationController(vsync: this, duration: _fade_ms);
    _fade = CurvedAnimation(parent: _fade_ctrl, curve: Curves.easeInOut);
    _now = DateTime.now();
    _clock_timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _fade_timer?.cancel();
    _fade_ctrl.dispose();
    _clock_timer.cancel();
    super.dispose();
  }

  void _onTouch(PointerDownEvent _) {
    _fade_ctrl.forward();
    _fade_timer?.cancel();
    _fade_timer = Timer(_hide_delay, () {
      if (mounted) _fade_ctrl.reverse();
    });
  }

  void _toggleNightMode() {
    widget.config_service.setNightMode(
      !widget.config_service.config.night_mode,
    );
  }

  String get _time => formatTime(
        _now.hour, _now.minute,
        widget.config_service.config.time_format,
        second: _now.second,
        include_seconds: true,
      );

  String get _night_time => formatTime(
        _now.hour, _now.minute,
        widget.config_service.config.time_format,
      );

  String get _date {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months   = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[_now.weekday - 1]}, ${months[_now.month - 1]} ${_now.day}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.config_service,
      builder: (context, child) {
        final night = widget.config_service.config.night_mode;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onTouch,
          child: Stack(
            children: [
              // ── night overlay: full-screen, outside SafeArea ──────────
              if (night)
                Container(color: Colors.black.withAlpha(200)),

              SafeArea(
                child: Stack(
                  children: [
                    // ── normal clock ────────────────────────────────────
                    if (!night) ...[
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _time,
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w100,
                                letterSpacing: 4,
                                color: noctuaText(context),
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _date,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 2,
                                color: noctuaText(context).withAlpha(178),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 20, left: 0, right: 0,
                        child: Opacity(
                          opacity: 0.12,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/logo.svg',
                              width: 48,
                              height: 48,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ── night time text ──────────────────────────────────
                    if (night)
                      Center(
                        child: Text(
                          _night_time,
                          style: TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.w100,
                            letterSpacing: 6,
                            color: Colors.white.withAlpha(40),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),

                    // ── moon toggle (top-left, mirrors gear top-right) ───
                    Positioned(
                      top: 0, left: 0,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12, left: 12),
                        child: FadeTransition(
                          opacity: _fade,
                          child: IconButton(
                            icon: Icon(
                              night
                                  ? Icons.bedtime
                                  : Icons.bedtime_outlined,
                              size: 22,
                              color: night
                                  ? Colors.white.withAlpha(160)
                                  : noctuaText(context).withAlpha(160),
                            ),
                            onPressed: _toggleNightMode,
                            tooltip: night ? 'Exit night mode' : 'Night mode',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
