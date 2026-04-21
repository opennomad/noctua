package com.opennomad.noctua

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Receives AlarmManager.setAlarmClock() broadcasts when an alarm or timer fires.
 *
 * Two-pronged approach for raising the app:
 *   1. Start AlarmRingtoneService (foreground service → MediaPlayer + fullScreenIntent).
 *   2. Call startActivity() directly — setAlarmClock BroadcastReceiver callbacks are
 *      exempt from Android 10+ background-activity-start restrictions without needing
 *      USE_FULL_SCREEN_INTENT.
 */
class AlarmFireReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
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

    // Direct raise — exempt from background-activity-start restrictions because
    // this BroadcastReceiver was triggered by AlarmManager.setAlarmClock().
    context.startActivity(
      Intent(context, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
      }
    )
  }
}
