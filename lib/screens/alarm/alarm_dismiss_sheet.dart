import 'package:flutter/material.dart';
import '../../services/alarm_service.dart';

/// Bottom sheet shown when an alarm notification fires while the app is active.
/// The user can dismiss the alarm or snooze it for 10 minutes.
class AlarmDismissSheet extends StatelessWidget {
  final String label;
  final int notif_id;
  const AlarmDismissSheet({super.key, required this.label, required this.notif_id});

  @override
  Widget build(BuildContext context) {
    final display = label.isEmpty ? 'Alarm' : label;
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Icon(Icons.alarm, size: 44, color: Colors.white.withAlpha(180)),
            const SizedBox(height: 16),
            Text(
              display,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 36),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.snooze, size: 18),
                    label: const Text('Snooze 10m'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      AlarmService.cancelAlarmNotif(notif_id);
                      Navigator.pop(context);
                      AlarmService.scheduleSnooze(label);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.alarm_off, size: 18),
                    label: const Text('Dismiss'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      AlarmService.cancelAlarmNotif(notif_id);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
