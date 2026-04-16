import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/config_service.dart';

class NightClockScreen extends StatefulWidget {
  final ConfigService config_service;
  const NightClockScreen({super.key, required this.config_service});

  @override
  State<NightClockScreen> createState() => _NightClockScreenState();
}

class _NightClockScreenState extends State<NightClockScreen> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _time => formatTime(
        _now.hour, _now.minute,
        widget.config_service.config.time_format,
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.config_service,
      builder: (context, child) => Container(
        color: Colors.black.withAlpha(160),
        child: Center(
          child: Text(
            _time,
            style: TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.w100,
              letterSpacing: 6,
              color: Colors.white.withAlpha(40),
            ),
          ),
        ),
      ),
    );
  }
}
