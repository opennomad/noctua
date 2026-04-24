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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.alarm, size: 22, color: Colors.white.withAlpha(180)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    display,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.snooze, size: 16),
                      label: const Text('Snooze 10m'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
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
                      icon: const Icon(Icons.alarm_off, size: 16),
                      label: const Text('Dismiss'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        AlarmService.cancelAlarmNotif(notif_id);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
