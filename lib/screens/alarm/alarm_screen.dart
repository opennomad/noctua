import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/color_schemes.dart';
import '../../config/config_service.dart';
import '../../services/alarm_service.dart';
import 'alarm_edit_sheet.dart';

class AlarmScreen extends StatefulWidget {
  final ConfigService config_service;
  const AlarmScreen({super.key, required this.config_service});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  static const _hide_delay = Duration(seconds: 3);
  static const _fade_ms    = Duration(milliseconds: 300);

  late AnimationController _ctrl;
  late Animation<double>   _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _fade_ms);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onTouch(PointerDownEvent _) {
    _ctrl.forward();
    _timer?.cancel();
    _timer = Timer(_hide_delay, () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onTouch,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: widget.config_service,
              builder: (ctx, child) {
                final alarms = widget.config_service.config.alarms;
                return Column(
                  children: [
                    _header(ctx),
                    Expanded(
                      child: alarms.isEmpty ? _empty(ctx) : _list(ctx, alarms),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Alarms',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
                color: noctuaText(ctx).withAlpha(128),
              ),
            ),
            const SizedBox(width: 4),
            FadeTransition(
              opacity: _fade,
              child: IconButton(
                icon: Icon(Icons.add, color: noctuaText(ctx).withAlpha(138), size: 18),
                onPressed: () => showAlarmEditSheet(ctx, widget.config_service),
                tooltip: 'Add alarm',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          ],
        ),
      );

  Widget _empty(BuildContext ctx) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm, size: 48, color: noctuaText(ctx).withAlpha(51)),
            const SizedBox(height: 20),
            Text(
              'No alarms',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
                color: noctuaText(ctx).withAlpha(102),
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => showAlarmEditSheet(ctx, widget.config_service),
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: noctuaText(ctx).withAlpha(77), width: 1),
                ),
                child: Icon(Icons.add, color: noctuaText(ctx), size: 26),
              ),
            ),
          ],
        ),
      );

  Widget _list(BuildContext ctx, List<AlarmConfig> alarms) =>
      ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: alarms.length,
        itemBuilder: (_, i) => _AlarmRow(
          alarm: alarms[i],
          config_service: widget.config_service,
          on_tap: () => showAlarmEditSheet(ctx, widget.config_service, alarm: alarms[i]),
        ),
      );
}

// ── alarm row ─────────────────────────────────────────────────────────────────

String _timeUntilAlarm(AlarmConfig alarm) {
  if (!alarm.enabled) return '';
  final now = DateTime.now();
  var at = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
  if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
  
  // For repeating alarms, find the next occurrence
  if (alarm.repeat_days.isNotEmpty) {
    for (int i = 0; i < 7; i++) {
      final check = now.add(Duration(days: i));
      if (alarm.repeat_days.contains(check.weekday - 1)) {
        at = DateTime(check.year, check.month, check.day, alarm.hour, alarm.minute);
        if (at.isAfter(now)) break;
      }
    }
  }
  
  final diff = at.difference(now);
  final hours = diff.inHours;
  final mins = diff.inMinutes % 60;
  
  if (hours > 24) {
    final days = hours ~/ 24;
    return 'in ${days}d ${hours % 24}h';
  } else if (hours > 0) {
    return 'in ${hours}h ${mins}m';
  } else if (mins > 0) {
    return 'in ${mins}m';
  } else {
    return 'now';
  }
}

class _AlarmRow extends StatefulWidget {
  final AlarmConfig alarm;
  final ConfigService config_service;
  final VoidCallback on_tap;

  const _AlarmRow({
    required this.alarm,
    required this.config_service,
    required this.on_tap,
  });

  @override
  State<_AlarmRow> createState() => _AlarmRowState();
}

class _AlarmRowState extends State<_AlarmRow> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update every minute to refresh "time until"
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggle(bool val) async {
    await widget.config_service.updateAlarm(widget.alarm.copyWith(enabled: val));
    await AlarmService.syncAll(widget.config_service.config.alarms);
  }

  @override
  Widget build(BuildContext context) {
    final alarm = widget.alarm;
    return GestureDetector(
      onTap: widget.on_tap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatTime(alarm.hour, alarm.minute,
                        widget.config_service.config.time_format),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w100,
                      letterSpacing: 2,
                      color: noctuaText(context).withAlpha(alarm.enabled ? 230 : 120),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Row(
                    children: [
                      if (alarm.label.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            alarm.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: noctuaText(context)
                                  .withAlpha(alarm.enabled ? 153 : 77),
                            ),
                          ),
                        ),
                        Text(' · ',
                            style: TextStyle(
                                color: noctuaText(context).withAlpha(51))),
                      ],
                      Flexible(
                        child: Text(
                          alarm.repeat_label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: noctuaText(context)
                                .withAlpha(alarm.enabled ? 102 : 51),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (alarm.enabled) ...[
              Text(
                _timeUntilAlarm(alarm),
                style: TextStyle(
                  fontSize: 12,
                  color: noctuaText(context).withAlpha(77),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Switch(
              value: alarm.enabled,
              onChanged: _toggle,
              activeThumbColor: noctuaText(context).withAlpha(178),
              activeTrackColor: noctuaText(context).withAlpha(61),
              inactiveThumbColor: noctuaText(context).withAlpha(61),
              inactiveTrackColor: noctuaText(context).withAlpha(31),
            ),
          ],
        ),
      ),
    );
  }
}
