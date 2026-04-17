import 'package:flutter/material.dart';
import '../../theme/color_schemes.dart';
import '../../config/config_service.dart';
import '../../services/alarm_service.dart';
import 'alarm_edit_sheet.dart';

class AlarmScreen extends StatelessWidget {
  final ConfigService config_service;
  const AlarmScreen({super.key, required this.config_service});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: config_service,
            builder: (ctx, child) {
              final alarms = config_service.config.alarms;
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
                  color: noctuaText(ctx).withAlpha(128),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add, color: noctuaText(ctx).withAlpha(138), size: 22),
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
              onTap: () => showAlarmEditSheet(ctx, config_service),
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
          config_service: config_service,
          on_tap: () => showAlarmEditSheet(ctx, config_service, alarm: alarms[i]),
        ),
      );
}

// ── alarm row ─────────────────────────────────────────────────────────────────

class _AlarmRow extends StatelessWidget {
  final AlarmConfig alarm;
  final ConfigService config_service;
  final VoidCallback on_tap;

  const _AlarmRow({
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
                        config_service.config.time_format),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w100,
                      letterSpacing: 2,
                      color: noctuaText(context).withAlpha(alarm.enabled ? 230 : 120),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (alarm.label.isNotEmpty) ...[
                        Text(
                          alarm.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: noctuaText(context)
                                .withAlpha(alarm.enabled ? 153 : 77),
                          ),
                        ),
                        Text(' · ',
                            style: TextStyle(
                                color: noctuaText(context).withAlpha(51))),
                      ],
                      Text(
                        alarm.repeat_label,
                        style: TextStyle(
                          fontSize: 13,
                          color: noctuaText(context)
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
