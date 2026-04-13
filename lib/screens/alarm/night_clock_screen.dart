import 'dart:async';
import 'package:flutter/material.dart';

class NightClockScreen extends StatefulWidget {
  const NightClockScreen({super.key});

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

  String get _time {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _time,
        style: TextStyle(
          fontSize: 80,
          fontWeight: FontWeight.w100,
          letterSpacing: 6,
          color: Colors.white.withAlpha(51),
        ),
      ),
    );
  }
}
