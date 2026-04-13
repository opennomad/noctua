import 'package:flutter/material.dart';
import '../../config/config_service.dart';
import '../../services/alarm_service.dart';
import 'alarm_edit_sheet.dart';

class AlarmScreen extends StatelessWidget {
  final ConfigService config_service;
  const AlarmScreen({super.key, required this.config_service});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: config_service,
        builder: (ctx, child) {
          final alarms = config_service.config.alarms;
          return Column(
            children: [
              _header(ctx),
              Expanded(
                child: alarms.isEmpty
                    ? _empty(ctx)
                    : _list(ctx, alarms),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Alarms',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                  color: Colors.white.withAlpha(128),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white54, size: 22),
              onPressed: () => showAlarmEditSheet(ctx, config_service),
              tooltip: 'Add alarm',
            ),
          ],
        ),
      );

  Widget _empty(BuildContext ctx) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm, size: 48, color: Colors.white.withAlpha(51)),
            const SizedBox(height: 20),
            Text(
              'No alarms',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
                color: Colors.white.withAlpha(102),
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => showAlarmEditSheet(ctx, config_service),
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withAlpha(77), width: 1),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              ),
            ),
          ],
        ),
      );

  Widget _list(BuildContext ctx, List<AlarmConfig> alarms) =>
      ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: alarms.length,
        itemBuilder: (_, i) => _AlarmCard(
          alarm: alarms[i],
          config_service: config_service,
          on_tap: () => showAlarmEditSheet(ctx, config_service,
              alarm: alarms[i]),
        ),
      );
}

// ── alarm card ────────────────────────────────────────────────────────────────

class _AlarmCard extends StatelessWidget {
  final AlarmConfig alarm;
  final ConfigService config_service;
  final VoidCallback on_tap;

  const _AlarmCard({
    required this.alarm,
    required this.config_service,
    required this.on_tap,
  });

  Future<void> _toggle(bool val) async {
    await config_service.updateAlarm(alarm.copyWith(enabled: val));
    await AlarmService.syncAll(config_service.config.alarms);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: on_tap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(alarm.enabled ? 15 : 8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withAlpha(alarm.enabled ? 30 : 15),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alarm.time_string,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w100,
                      letterSpacing: 2,
                      color: Colors.white
                          .withAlpha(alarm.enabled ? 230 : 120),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (alarm.label.isNotEmpty) ...[
                        Text(
                          alarm.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white
                                .withAlpha(alarm.enabled ? 153 : 77),
                          ),
                        ),
                        Text(
                          ' · ',
                          style: TextStyle(
                              color: Colors.white.withAlpha(51)),
                        ),
                      ],
                      Text(
                        alarm.repeat_label,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white
                              .withAlpha(alarm.enabled ? 102 : 51),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: alarm.enabled,
              onChanged: _toggle,
              activeThumbColor: Colors.white70,
              activeTrackColor: Colors.white24,
              inactiveThumbColor: Colors.white24,
              inactiveTrackColor: Colors.white12,
            ),
          ],
        ),
      ),
    );
  }
}
