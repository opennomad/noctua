import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/config_service.dart';

class ClockScreen extends StatefulWidget {
  final ConfigService config_service;
  const ClockScreen({super.key, required this.config_service});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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
        second: _now.second,
        include_seconds: true,
      );

  String get _date {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final wd = weekdays[_now.weekday - 1];
    final mo = months[_now.month - 1];
    return '$wd, $mo ${_now.day}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.config_service,
      builder: (context, child) => SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _time,
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w100,
                  letterSpacing: 4,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _date,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                  color: Colors.white.withAlpha(178),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
