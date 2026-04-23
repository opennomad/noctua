package com.opennomad.noctua

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager

/**
 * Receives AlarmManager.setAlarmClock() broadcasts when an alarm or timer fires.
 *
 * Two-pronged approach for raising the app:
 *   1. Start AlarmRingtoneService first — posts the fullScreenIntent notification
 *      while the screen is still off, so Android fires it as a true full-screen
 *      activity rather than a heads-up banner.
 *   2. Call startActivity(AlarmActivity) directly as a fallback for devices where
 *      fullScreenIntent is blocked; setAlarmClock BroadcastReceiver callbacks are
 *      exempt from Android 10+ background-activity-start restrictions.
 *
 * AlarmRingtoneService posts a fullScreenIntent notification that wakes the screen
 * and shows AlarmActivity on the lock screen. Android docs confirm FLAG_TURN_SCREEN_ON
 * (set in AlarmActivity) paired with fullScreenIntent wakes the device without needing
 * ACQUIRE_CAUSES_WAKEUP. A PARTIAL_WAKE_LOCK here just keeps the CPU alive long enough
 * for startForeground() to fire — the system's fullScreenIntent machinery takes over
 * from there.
 *
 * We do NOT call startActivity(AlarmActivity) here. The fullScreenIntent is the sole
 * launch path; a second startActivity would race it and produce a visible flicker.
 */
class AlarmFireReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    AlarmCountdownService.cancel(context)

    val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    val wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "noctua:alarm_wake")
    wakeLock.acquire(10_000L)

    val svc = Intent(context, AlarmRingtoneService::class.java).also {
      it.putExtra("sound_uri",      intent.getStringExtra("sound_uri")       ?: "")
      it.putExtra("name",           intent.getStringExtra("name")            ?: "")
      it.putExtra("type",           intent.getStringExtra("type")            ?: "alarm")
      it.putExtra("crescendo_secs", intent.getIntExtra("crescendo_secs", 30))
      it.putExtra("snooze_mins",    intent.getIntExtra("snooze_mins", 10))
      it.putExtra("add_mins",       intent.getIntExtra("add_mins",     1))
      it.putExtra("req_code",       intent.getIntExtra("req_code",     0))
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      context.startForegroundService(svc)
    } else {
      context.startService(svc)
    }
  }
}
